// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.2;

import "target/{{VERSION}}.sol";

interface IHalmosVM {
    function assume(bool condition) external;
    function prank(address msgSender) external;
    function deal(address account, uint256 newBalance) external;
    function load(address account, bytes32 slot) external view returns (bytes32);
}

contract BankTest {
    IHalmosVM constant vm = IHalmosVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    Bank bank;

    // Helper function to read credits directly from EVM storage
    function getCredits(address user) internal view returns (uint256) {
        bytes32 slot = keccak256(abi.encodePacked(uint256(uint160(user)), uint256(0)));
        bytes32 value = vm.load(address(bank), slot);
        return uint256(value);
    }

    /// @notice Property: deposit-assets-credit-others
    function check_deposit_assets_credit_others(
        address caller,
        address targetUser,
        uint256 depositAmount,
        uint256 initialBalance,
        uint256 limitAmount
    ) public {
        {{CONSTRUCTOR_SETUP}};

        vm.assume(caller != address(0));
        vm.assume(targetUser != address(0));
        vm.assume(targetUser != address(bank));
        vm.assume(caller != targetUser);

        vm.assume(depositAmount > 0);
        vm.assume(initialBalance >= depositAmount);
        vm.assume(limitAmount > 0);
        
        // Give eth to caller 
        vm.deal(caller, initialBalance);

        uint256 targetCreditsBefore = getCredits(targetUser);

        vm.prank(caller);
        
        try bank.deposit{value: depositAmount}() {
            uint256 targetCreditsAfter = getCredits(targetUser);
            assert(targetCreditsAfter == targetCreditsBefore);
        } catch {}
    }
}