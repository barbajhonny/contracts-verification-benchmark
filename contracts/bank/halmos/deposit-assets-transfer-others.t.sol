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

    /// @notice Property: deposit-assets-transfer-others
    function check_deposit_assets_transfer_others(
        address caller,
        address targetUser,
        uint256 depositAmount,
        uint256 initialBalance
    ) public {
        vm.assume(caller != address(0));
        vm.assume(targetUser != address(0));
        vm.assume(caller != targetUser);
        
        vm.assume(targetUser != address(bank));

        vm.assume(depositAmount > 0 && depositAmount <= 100 ether);
        vm.assume(initialBalance >= depositAmount);
        vm.assume(initialBalance <= 1000 ether);

        vm.deal(caller, initialBalance);
        vm.deal(targetUser, initialBalance);

        uint256 targetEthBefore = targetUser.balance;

        vm.prank(caller);
        
        try bank.deposit{value: depositAmount}() {
            uint256 targetEthAfter = targetUser.balance;
            assert(targetEthAfter == targetEthBefore);
        } catch {}
    }
}