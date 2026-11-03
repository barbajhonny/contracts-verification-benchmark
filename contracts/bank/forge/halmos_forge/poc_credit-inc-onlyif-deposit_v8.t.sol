// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.2;

import {Test} from "forge-std/Test.sol";
import {Bank} from "versions/Bank_v8.sol";

// Contract user. Mirrors BankUser: reacts at most once per transaction (`reacted`).
// The reaction is configured per test with the choices used by Halmos:
//   choice 0: accepts and does nothing
//   choice 2: calls Bank itself with `data` and `value` (receive_peer_acts = false)
//   choice 3: forwards `value` wei to `to`
// In every case the outcome of the call is ignored, as in BankUser.
contract User {
    Bank public bank;
    bool public reacted;
    uint8 public choice;
    address public to;
    bytes public data;
    uint256 public value;

    function setBank(Bank _bank) external { bank = _bank; }

    function newTransaction() external { reacted = false; }

    function setReaction(uint8 _choice, address _to, bytes calldata _data, uint256 _value) external {
        choice = _choice;
        to = _to;
        data = _data;
        value = _value;
    }

    receive() external payable {
        if (reacted) return;
        reacted = true;
        if (choice == 2) {
            (bool ok,) = address(bank).call{value: value}(data);
            ok;
        } else if (choice == 3) {
            (bool ok,) = payable(to).call{value: value}("");
            ok;
        }
    }
}

// Halmos counterexample (log: v8_credit-inc-onlyif-deposit.log):
//   halmos_A_address = 0xaaaa0004 (userContract0 = u0)
//   tx1: sender = userContract1 (u1), deposit()   p_value = 0x122a44c80000000000000000000000
//   tx2: sender = u1, withdraw(p_amount)           p_amount = 0xd9bdff00000000000000000000000
//        the low-level call in `withdraw` calls u1.receive:
//          receive_choice = 3, receive_to = 0xaaaa0004 (u0),
//          receive_transfer_value = 0x9f000000000000000000000000000
//        u0.receive: receive_choice = 2, receive_peer_acts = 0,
//          calldata = deposit(), receive_call_value = 0x5c000000000000000000000000000
// The bug: only `withdraw` is nonReentrant; `deposit` can still be called during the
// low-level call of `withdraw`, so A's (u0) credit increases during a `withdraw` sent by u1.
contract PoC_CreditIncOnlyifDeposit_v8 is Test {

    Bank bank;
    User u0;
    User u1;

    function setUp() public {
        bank = new Bank();
        u0 = new User();
        u1 = new User();
        u0.setBank(bank);
        u1.setBank(bank);
    }

    // v8 inherits ReentrancyGuard: `_status` is in slot 0, `credits` in slot 1
    function _credits(address who) internal view returns (uint256) {
        return uint256(vm.load(address(bank), keccak256(abi.encode(who, uint256(1)))));
    }

    function test_poc_credit_inc_onlyif_deposit() public {
        uint256 value = 0x122a44c80000000000000000000000;
        uint256 amount = 0xd9bdff00000000000000000000000;

        // tx1: u1 deposits
        u0.newTransaction();
        u1.newTransaction();
        vm.deal(address(u1), value);
        vm.prank(address(u1));
        bank.deposit{value: value}();

        // tx2: u1 withdraws; u1 forwards ETH to u0, u0 deposits
        u0.newTransaction();
        u1.newTransaction();
        u1.setReaction(3, address(u0), "", 0x9f000000000000000000000000000);
        u0.setReaction(2, address(0), abi.encodeWithSignature("deposit()"), 0x5c000000000000000000000000000);
        uint256 creditBefore = _credits(address(u0));

        vm.prank(address(u1));
        (bool ok,) = address(bank).call(abi.encodeWithSignature("withdraw(uint256)", amount));
        assertTrue(ok, "withdraw reverted: counterexample not reproduced");

        uint256 creditAfter = _credits(address(u0));

        // property: if A's credit increased, the tx must be a `deposit` sent by A.
        // Here the tx is a `withdraw` sent by u1.
        assertGt(creditAfter, creditBefore, "credit-inc-onlyif-deposit holds: counterexample not reproduced");
    }
}
