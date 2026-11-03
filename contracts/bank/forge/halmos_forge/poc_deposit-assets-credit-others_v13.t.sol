// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.2;

import {Test} from "forge-std/Test.sol";
import {Bank} from "versions/Bank_v13.sol";

// Contract user. Mirrors BankUser: reacts at most once per transaction (`reacted`).
// The reaction chosen by Halmos for the owner is receive_choice = 2,
// receive_peer_acts = false: the user itself calls Bank with `data` and `value`,
// ignoring the outcome (as in BankUser.act).
contract User {
    Bank public bank;
    bool public reacted;
    bytes public data;
    uint256 public value;

    function setBank(Bank _bank) external { bank = _bank; }

    function newTransaction() external { reacted = false; }

    function setReentry(bytes calldata _data, uint256 _value) external {
        data = _data;
        value = _value;
    }

    receive() external payable {
        if (reacted) return;
        reacted = true;
        if (data.length == 0) return; // receive_choice = 0
        (bool ok,) = address(bank).call{value: value}(data);
        ok;
    }
}

// Halmos counterexample (log: v13_deposit-assets-credit-others.log):
//   halmos_owner_address = 0xaaaa0004 (userContract0 = u0)
//   halmos_A_address     = 0xaaaa0004 (u0)
//   tx1: sender = userContract1 (u1), deposit()   p_value = 0x100000000000000000000000000000000
//        `payable(owner).transfer(1)` calls u0.receive:
//          receive_choice = 2, receive_peer_acts = 0,
//          calldata = deposit(), receive_call_value = 0x01
// In the Halmos trace u0's deposit of 1 wei is executed inside the `transfer(1)`,
// so A's (u0) credit increases during a `deposit` sent by u1.
// This PoC checks whether the sequence is executable on the real EVM.
contract PoC_DepositAssetsCreditOthers_v13 is Test {

    Bank bank;
    User u0;
    User u1;

    function setUp() public {
        u0 = new User();
        u1 = new User();
        // u0 is the owner: it deploys Bank
        vm.prank(address(u0));
        bank = new Bank();
        u0.setBank(bank);
        u1.setBank(bank);
    }

    function _credits(address who) internal view returns (uint256) {
        return uint256(vm.load(address(bank), keccak256(abi.encode(who, uint256(0)))));
    }

    function test_poc_deposit_assets_credit_others() public {
        uint256 value = 0x100000000000000000000000000000000;

        u0.newTransaction();
        u1.newTransaction();
        u0.setReentry(abi.encodeWithSignature("deposit()"), 1);
        vm.deal(address(u1), value);
        uint256 creditBefore = _credits(address(u0));

        // tx1: u1 deposits; the transfer(1) to the owner u0 triggers u0's deposit of 1 wei
        vm.prank(address(u1));
        (bool ok,) = address(bank).call{value: value}(abi.encodeWithSignature("deposit()"));
        assertTrue(ok, "deposit reverted (the reentrant receive does not complete inside transfer): counterexample not reproduced");

        uint256 creditAfter = _credits(address(u0));

        // property: after a non-reverting deposit, the credit of any user but the sender is preserved
        assertNotEq(creditAfter, creditBefore, "deposit-assets-credit-others holds: counterexample not reproduced");
    }
}
