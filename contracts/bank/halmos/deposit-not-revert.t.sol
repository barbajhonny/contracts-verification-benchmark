// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.2;

import "target/{{VERSION}}.sol";

interface IHalmosVM {
    function assume(bool condition) external;
    function prank(address msgSender) external;
    function deal(address account, uint256 newBalance) external;
}

contract BankTest {
    IHalmosVM constant vm = IHalmosVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    Bank bank;

    /// @notice Property: deposit-not-revert
    function check_deposit_not_revert(
        address caller,
        uint256 depositAmount,
        uint256 amount,
        uint256 initialBalance,
        uint256 limitAmount
    ) public {

        vm.assume(limitAmount > 0);

        {{CONSTRUCTOR_SETUP}};

        vm.assume(caller != address(0) && caller != address(this));

        vm.assume(initialBalance >= depositAmount);
        vm.deal(caller, initialBalance);

        // Deposit
        vm.prank(caller);
        bank.deposit{value: depositAmount}();
    }
}