// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.2;

import {Test} from "forge-std/Test.sol";
import {Bank} from "versions/Bank_v5.sol";

// Contract user (userContract1 = 0xaaaa0005 in the counterexample).
contract User {}

// Halmos counterexample (log: v5_deposit-assets-credit.log):
//   tx1: sender = userContract1 (sender_is_contract = 1, sender_is_contract0 = 0)
//        deposit()   p_value = 0x100000000000000000000000000000000
// The bug: credits[msg.sender] += msg.value + 1
contract PoC_DepositAssetsCredit_v5 is Test {

    Bank bank;
    User user;

    function setUp() public {
        bank = new Bank();
        user = new User();
    }

    function _credits(address who) internal view returns (uint256) {
        return uint256(vm.load(address(bank), keccak256(abi.encode(who, uint256(0)))));
    }

    function test_poc_deposit_assets_credit() public {
        uint256 value = 0x100000000000000000000000000000000;
        vm.deal(address(user), value);

        uint256 creditBefore = _credits(address(user));

        vm.prank(address(user));
        (bool ok,) = address(bank).call{value: value}(abi.encodeWithSignature("deposit()"));
        assertTrue(ok, "deposit() reverted: counterexample not reproduced");

        uint256 creditAfter = _credits(address(user));

        // property: after a non-reverting deposit, the sender's credit increases by msg.value
        assertNotEq(creditAfter - creditBefore, value, "deposit-assets-credit holds: counterexample not reproduced");
    }
}
