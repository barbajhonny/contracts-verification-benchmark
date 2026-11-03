// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.2;

import {Test} from "forge-std/Test.sol";
import {Bank} from "versions/Bank_v10.sol";

// Contract user. Mirrors BankUser: reacts at most once per transaction (`reacted`),
// and the reacting call can be executed by the user itself or by its `peer` (`act`).
//   choice 0: accepts and does nothing
//   choice 2: `actor` calls Bank with `data` and `value`; actor = peer if peerActs, else this
//   choice 3: forwards `value` wei to `to`
// In every case the outcome of the call is ignored, as in BankUser.
contract User {
    Bank public bank;
    User public peer;
    bool public reacted;
    uint8 public choice;
    bool public peerActs;
    address public to;
    bytes public data;
    uint256 public value;

    function setBank(Bank _bank) external { bank = _bank; }

    function setPeer(User _peer) external { peer = _peer; }

    function newTransaction() external { reacted = false; }

    function setReaction(uint8 _choice, bool _peerActs, address _to, bytes calldata _data, uint256 _value) external {
        choice = _choice;
        peerActs = _peerActs;
        to = _to;
        data = _data;
        value = _value;
    }

    receive() external payable {
        if (reacted) return;
        reacted = true;
        if (choice == 2) {
            User actor = peerActs ? peer : this;
            actor.act(data, value);
        } else if (choice == 3) {
            (bool ok,) = payable(to).call{value: value}("");
            ok;
        }
    }

    // call to Bank performed by this user (msg.sender = this), as BankUser.act
    function act(bytes memory _data, uint256 _value) external {
        require(msg.sender == address(this) || msg.sender == address(peer));
        (bool ok,) = address(bank).call{value: _value}(_data);
        ok;
    }
}

// Halmos counterexample (log: v10_credit-dec-onlyif-withdraw.log):
//   halmos_owner_address = 0x8000000000000000000000000000000000000000
//   halmos_A_address     = 0xaaaa0004 (userContract0 = u0)
//   tx1: sender = userContract1 (u1), deposit()     p_value  = 0x100000000000000000000000000000000
//   tx2: sender = u1, withdraw(0x80000000000000000000000000000000)
//        u1.receive: receive_choice = 3, receive_to = 0xaaaa0004 (u0),
//                    receive_transfer_value = 0x80000000000000000000000000000000
//        u0.receive: receive_choice = 2, receive_peer_acts = 0, calldata = deposit(),
//                    receive_call_value = 0x80000000000000000000000000000000
//   tx3: sender = u1, withdraw(1)
//        u1.receive: receive_choice = 2, receive_peer_acts = 1 (u0 acts),
//                    calldata = withdraw(1), receive_call_value = 0
//        u0.receive: receive_choice = 0
// The bug: the low-level call in `withdraw` gives control to u1, which makes u0 withdraw:
// A's (u0) credit decreases during a `withdraw` whose sender is u1.
// The pause flag of v10 is never set (owner never calls setP).
contract PoC_CreditDecOnlyifWithdraw_v10 is Test {

    Bank bank;
    User u0;
    User u1;
    address constant OWNER = 0x8000000000000000000000000000000000000000;

    function setUp() public {
        vm.prank(OWNER);
        bank = new Bank();
        u0 = new User();
        u1 = new User();
        u0.setBank(bank);
        u1.setBank(bank);
        u0.setPeer(u1);
        u1.setPeer(u0);
    }

    function _credits(address who) internal view returns (uint256) {
        return uint256(vm.load(address(bank), keccak256(abi.encode(who, uint256(0)))));
    }

    function _newTransaction() internal {
        u0.newTransaction();
        u1.newTransaction();
    }

    function test_poc_credit_dec_onlyif_withdraw() public {
        uint256 value = 0x100000000000000000000000000000000;
        uint256 half = 0x80000000000000000000000000000000;

        // tx1: u1 deposits
        _newTransaction();
        vm.deal(address(u1), value);
        vm.prank(address(u1));
        bank.deposit{value: value}();

        // tx2: u1 withdraws; u1 forwards ETH to u0, u0 deposits it
        _newTransaction();
        u1.setReaction(3, false, address(u0), "", half);
        u0.setReaction(2, false, address(0), abi.encodeWithSignature("deposit()"), half);
        vm.prank(address(u1));
        bank.withdraw(half);
        assertEq(_credits(address(u0)), half, "tx2: u0 did not deposit");

        // tx3: u1 withdraws 1 wei; u1.receive makes u0 (peer) withdraw 1 wei
        _newTransaction();
        u1.setReaction(2, true, address(0), abi.encodeWithSignature("withdraw(uint256)", uint256(1)), 0);
        u0.setReaction(0, false, address(0), "", 0);
        uint256 creditBefore = _credits(address(u0));

        vm.prank(address(u1));
        bank.withdraw(1);

        uint256 creditAfter = _credits(address(u0));

        // property: if A's credit decreased, the tx must be a `withdraw` whose sender is A.
        // Here the tx is a `withdraw`, but the sender is u1, not A (u0).
        assertLt(creditAfter, creditBefore, "credit-dec-onlyif-withdraw holds: counterexample not reproduced");
    }
}
