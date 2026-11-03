// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.2;

import {Test} from "forge-std/Test.sol";
import {Bank} from "versions/Bank_v7.sol";

// Contract user (userContract1 = 0xaaaa0005 in the counterexample), the depositor.
contract User {}

// Halmos counterexample (log: v7_deposit-assets-credit-others.log):
//   halmos_owner_address = 0x8000000000000000000000000000000000000000
//   halmos_A_address     = 0x8000000000000000000000000000000000000000 (A is the owner)
//   tx1: sender = userContract1 (sender_is_contract = 1, sender_is_contract0 = 0)
//        deposit()   p_value = 0x100000000000000000000000000000000
// The bug: `deposit` also does credits[owner] += 1, so the credit of A (the owner)
// changes during a deposit sent by someone else.
contract PoC_DepositAssetsCreditOthers_v7 is Test {

    Bank bank;
    User user;
    address constant OWNER = 0x8000000000000000000000000000000000000000;

    function setUp() public {
        vm.prank(OWNER);
        bank = new Bank();
        user = new User();
    }

    function _credits(address who) internal view returns (uint256) {
        return uint256(vm.load(address(bank), keccak256(abi.encode(who, uint256(0)))));
    }

    function test_poc_deposit_assets_credit_others() public {
        uint256 value = 0x100000000000000000000000000000000;
        vm.deal(address(user), value);

        uint256 creditBefore = _credits(OWNER);

        vm.prank(address(user));
        (bool ok,) = address(bank).call{value: value}(abi.encodeWithSignature("deposit()"));
        assertTrue(ok, "deposit() reverted: counterexample not reproduced");

        uint256 creditAfter = _credits(OWNER);

        // property: after a non-reverting deposit, the credit of any user but the sender is preserved
        assertNotEq(address(user), OWNER);
        assertNotEq(creditAfter, creditBefore, "deposit-assets-credit-others holds: counterexample not reproduced");
    }
}
