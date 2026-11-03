// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.2;

import {Test} from "forge-std/Test.sol";
import {Bank} from "versions/Bank_v12.sol";

// Contract user (userContract1 = 0xaaaa0005 in the counterexample).
// Mirrors BankUser with receive_choice = 1: the receive reverts.
contract User {
    bool public reacted;
    bool public rejects;

    function newTransaction() external { reacted = false; }

    function setRejects(bool r) external { rejects = r; }

    receive() external payable {
        if (reacted) return;
        reacted = true;
        if (rejects) revert(); // receive_choice = 1
    }
}

// Halmos counterexample (log: v12_withdraw-sender-rcv.log):
//   tx1: sender = userContract1, deposit()          p_value  = 0x100000000000000000000000000000000
//   tx2: sender = userContract1, withdraw(p_amount)  p_amount = 0x100000000000000000000000000000000
//        the low-level call in `withdraw` calls the receive of userContract1:
//        receive_choice = 1 (revert)
// The bug: `withdraw` does not check `success`, so it does not revert even though
// no ETH was transferred: the sender's balance does not increase by amount.
contract PoC_WithdrawSenderRcv_v12 is Test {

    Bank bank;
    User user;

    function setUp() public {
        bank = new Bank();
        user = new User();
    }

    function test_poc_withdraw_sender_rcv() public {
        uint256 value = 0x100000000000000000000000000000000;
        uint256 amount = 0x100000000000000000000000000000000;

        // tx1: userContract1 deposits
        user.newTransaction();
        vm.deal(address(user), value);
        vm.prank(address(user));
        bank.deposit{value: value}();

        // tx2: userContract1 withdraws; its receive reverts
        user.newTransaction();
        user.setRejects(true);
        uint256 balanceBefore = address(user).balance;

        vm.prank(address(user));
        (bool ok,) = address(bank).call(abi.encodeWithSignature("withdraw(uint256)", amount));
        assertTrue(ok, "withdraw reverted: counterexample not reproduced");

        uint256 balanceAfter = address(user).balance;

        // property: after a non-reverting withdraw(amount), the sender's balance increases by amount
        assertNotEq(balanceAfter - balanceBefore, amount, "withdraw-sender-rcv holds: counterexample not reproduced");
    }
}
