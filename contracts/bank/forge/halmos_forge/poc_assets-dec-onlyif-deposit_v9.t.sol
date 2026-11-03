// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.2;

import {Test} from "forge-std/Test.sol";
import {Bank} from "versions/Bank_v9.sol";

// Contract user A (halmos_A_address = 0xaaaa0005 = userContract1 in the counterexample).
// Its receive() implements only the behaviour chosen by Halmos:
//   transferValue == 0 => receive_choice = 0 (accepts, does nothing)
//   transferValue >  0 => receive_choice = 3 (forwards `transferValue` wei to `to`)
contract A {
    address public to;
    uint256 public transferValue;

    function setTransfer(address _to, uint256 v) external { to = _to; transferValue = v; }

    receive() external payable {
        if (transferValue > 0) {
            uint256 v = transferValue;
            transferValue = 0; // reacts at most once, like `reacted` in BankUser
            (bool ok,) = payable(to).call{value: v}("");
            ok; // the outcome is irrelevant, as in BankUser
        }
    }
}

// Halmos counterexample (log: v9_assets-dec-onlyif-deposit.log), sender is always A:
//   tx1: deposit()                                    p_value  = 0x100000000000000000000000000000000
//   tx2: withdraw(0xfffffffffffffffffffffffe00000000)  receive_choice = 0
//   tx3: withdraw(1)                                  receive_choice = 3,
//        receive_to = 0x8000000000000000000000000000000000000000,
//        receive_transfer_value = 0x600000001
// The bug: the low-level call in `withdraw` gives control to msg.sender (nonReentrant does not
// prevent it from calling other contracts), and A sends away more ETH than it received.
contract PoC_AssetsDecOnlyifDeposit_v9 is Test {

    Bank bank;
    A a;

    function setUp() public {
        bank = new Bank();
        a = new A();
    }

    function test_poc_assets_dec_onlyif_deposit() public {
        uint256 value = 0x100000000000000000000000000000000;
        vm.deal(address(a), value);
        vm.prank(address(a));
        bank.deposit{value: value}();

        // tx2: A withdraws, its receive() does nothing
        vm.prank(address(a));
        bank.withdraw(0xfffffffffffffffffffffffe00000000);

        // tx3: A withdraws 1 wei, its receive() forwards 0x600000001 wei to an EOA
        a.setTransfer(0x8000000000000000000000000000000000000000, 0x600000001);
        uint256 balanceBefore = address(a).balance;

        vm.prank(address(a));
        bank.withdraw(1);

        uint256 balanceAfter = address(a).balance;

        // property: if A's balance decreased, the tx must be a `deposit` by A.
        // Here A's balance decreased, but the tx was a `withdraw`.
        assertLt(balanceAfter, balanceBefore, "assets-dec-onlyif-deposit holds: counterexample not reproduced");
    }
}
