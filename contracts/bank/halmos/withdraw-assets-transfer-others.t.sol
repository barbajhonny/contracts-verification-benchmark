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

    function setUp() public {
        {{CONSTRUCTOR_SETUP}};
    }

    /// @notice Property: withdraw-assets-transfer-others
    function check_withdraw_assets_transfer_others(
        address caller,
        address otherUser,
        uint256 depositAmount,
        uint256 withdrawAmount,
        uint256 otherDepositAmount
    ) public {
        vm.assume(caller != address(0) && caller != address(bank));
        vm.assume(otherUser != address(0) && otherUser != address(bank));
        vm.assume(caller != otherUser);

        vm.assume(depositAmount > 0 && depositAmount <= 100 ether);
        vm.assume(otherDepositAmount > 0 && otherDepositAmount <= 100 ether);
        vm.assume(withdrawAmount > 0 && withdrawAmount <= depositAmount);

        vm.deal(caller, 200 ether);
        vm.deal(otherUser, 200 ether);

        vm.prank(otherUser);
        bank.deposit{value: otherDepositAmount}();

        vm.prank(caller);
        bank.deposit{value: depositAmount}();

        uint256 otherEthBalanceBefore = otherUser.balance;

        vm.prank(caller);
        bank.withdraw(withdrawAmount);

        uint256 otherEthBalanceAfter = otherUser.balance;
        assert(otherEthBalanceAfter == otherEthBalanceBefore);
    }
}