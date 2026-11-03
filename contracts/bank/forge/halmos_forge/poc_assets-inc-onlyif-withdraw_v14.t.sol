// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.2;

import {Test} from "forge-std/Test.sol";
import {Bank} from "versions/Bank_v14.sol";

// Contract user (userContract1 = 0xaaaa0005 in the counterexample).
// Mirrors BankUser with receive_choice = 3: forwards `transferValue` wei to `to`,
// ignoring the outcome. Reacts at most once per transaction (`reacted`).
contract User {
    bool public reacted;
    address public to;
    uint256 public transferValue;

    function newTransaction() external { reacted = false; }

    function setTransfer(address _to, uint256 v) external { to = _to; transferValue = v; }

    receive() external payable {
        if (reacted) return;
        reacted = true;
        if (transferValue == 0) return; // receive_choice = 0
        (bool ok,) = payable(to).call{value: transferValue}("");
        ok;
    }
}

// Halmos counterexample (log: v14_assets-inc-onlyif-withdraw.log):
//   halmos_owner_address = 0x8000000000000000000000000000000000000000
//   halmos_A_address     = 0x8000000000000000000000000000000000000000 (an EOA)
//   tx1: sender = userContract1, deposit()          p_value  = 0x100000000000000000000000000000000
//   tx2: sender = userContract1, withdraw(p_amount)  p_amount = 0x100000000000000000000000000000000
//        the low-level call in `withdraw` calls the receive of userContract1:
//        receive_choice = 3, receive_to = 0x8000...0000 (A),
//        receive_transfer_value = 0x180000000
// The bug: the low-level call gives control to the sender, which sends ETH to A:
// A's balance increases during a `withdraw` that A did not send.
// The blacklist of v14 is never used (owner never calls setl).
contract PoC_AssetsIncOnlyifWithdraw_v14 is Test {

    Bank bank;
    User user;
    address constant OWNER = 0x8000000000000000000000000000000000000000;
    address constant A = 0x8000000000000000000000000000000000000000;

    function setUp() public {
        vm.prank(OWNER);
        bank = new Bank();
        user = new User();
    }

    function test_poc_assets_inc_onlyif_withdraw() public {
        uint256 value = 0x100000000000000000000000000000000;
        uint256 amount = 0x100000000000000000000000000000000;

        // tx1: userContract1 deposits
        user.newTransaction();
        vm.deal(address(user), value);
        vm.prank(address(user));
        bank.deposit{value: value}();

        // tx2: userContract1 withdraws; its receive sends 0x180000000 wei to A
        user.newTransaction();
        user.setTransfer(A, 0x180000000);
        uint256 balanceBefore = A.balance;

        vm.prank(address(user));
        bank.withdraw(amount);

        uint256 balanceAfter = A.balance;

        // property: if A's balance increased, the tx must be a `withdraw` sent by A.
        // Here the tx is a `withdraw` sent by userContract1.
        assertNotEq(address(user), A);
        assertGt(balanceAfter, balanceBefore, "assets-inc-onlyif-withdraw holds: counterexample not reproduced");
    }
}
