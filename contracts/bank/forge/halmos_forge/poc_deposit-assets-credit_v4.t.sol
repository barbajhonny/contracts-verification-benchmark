// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.2;

import {Test} from "forge-std/Test.sol";
import {Bank} from "versions/Bank_v4.sol";

// Counterexample from: build/halmos/logs/v4_deposit-assets-credit.log
// p_value_uint256 = 0x100000000000000000000000000000000
// The bug: credits[msg.sender] += msg.value - 1  (off-by-one)
contract PoC_DepositAssetsCredit_v4 is Test {

    Bank bank;

    function setUp() public {
        bank = new Bank();
    }

    function test_poc_deposit_assets_credit() public {
        address sender = makeAddr("sender");
        uint256 value = 0x100000000000000000000000000000000;

        vm.deal(sender, value);

        // credits is private: read slot 0 directly (mapping key => keccak256(key . slot))
        bytes32 slot = keccak256(abi.encode(sender, uint256(0)));
        uint256 creditBefore = uint256(vm.load(address(bank), slot));

        vm.prank(sender);
        (bool ok,) = address(bank).call{value: value}(abi.encodeWithSignature("deposit()"));
        assertTrue(ok, "deposit() reverted unexpectedly");

        uint256 creditAfter = uint256(vm.load(address(bank), slot));

        // property: creditAfter - creditBefore == value
        // on v4 this FAILS because deposit does: credits[msg.sender] += msg.value - 1
        assertEq(creditAfter - creditBefore, value, "deposit-assets-credit violated");
    }
}
