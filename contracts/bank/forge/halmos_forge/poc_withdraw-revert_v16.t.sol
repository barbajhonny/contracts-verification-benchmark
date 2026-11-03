// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.2;

import {Test} from "forge-std/Test.sol";
import {Bank} from "versions/Bank_v16.sol";

// Contract user (userContract1 = 0xaaaa0005 in the counterexample).
contract User {
    receive() external payable {}
}

// Halmos counterexample (log: v16_withdraw-revert.log):
//   tx1: sender = userContract1 (sender_is_contract = 1, sender_is_contract0 = 0)
//        withdraw(p_amount)   p_amount = 0x8000000000000000000000000000000000000000000000000000000000000000
//        (no previous deposit: the sender's credit is 0, the Bank balance is 0)
// The bug: no `amount <= credits[msg.sender]` check, unchecked decrement and no
// `require(success)`: the decrement wraps around, the low-level call fails because
// Bank has no ETH, and `withdraw` returns without reverting.
contract PoC_WithdrawRevert_v16 is Test {

    Bank bank;
    User user;

    function setUp() public {
        bank = new Bank();
        user = new User();
    }

    function _credits(address who) internal view returns (uint256) {
        return uint256(vm.load(address(bank), keccak256(abi.encode(who, uint256(0)))));
    }

    function test_poc_withdraw_revert() public {
        uint256 amount = 0x8000000000000000000000000000000000000000000000000000000000000000;
        uint256 creditBefore = _credits(address(user));

        vm.prank(address(user));
        (bool ok,) = address(bank).call(abi.encodeWithSignature("withdraw(uint256)", amount));

        // property: withdraw(amount) reverts if amount is 0 or greater than the sender's credit
        assertGt(amount, creditBefore, "precondition: amount must exceed the sender's credit");
        assertTrue(ok, "withdraw-revert holds: counterexample not reproduced");
    }
}
