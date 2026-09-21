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

    /// @notice Property: deposit-not-revert-external
    function check_deposit_not_revert_external(
        address caller,
        uint256 depositAmount,
        uint256 initialBalance,
        uint256 limitAmount
    ) public {
        {{CONSTRUCTOR_SETUP}};

        vm.assume(caller != address(0));
        vm.assume(caller != address(bank));
        vm.assume(caller != address(vm));

        vm.assume(initialBalance >= depositAmount);
        vm.assume(limitAmount > 0);
        vm.deal(caller, initialBalance);

        vm.prank(caller);
        (bool success,) = address(bank).call{value: depositAmount}(
            abi.encodeWithSelector(Bank.deposit.selector)
        );

        assert(success);
    }
}