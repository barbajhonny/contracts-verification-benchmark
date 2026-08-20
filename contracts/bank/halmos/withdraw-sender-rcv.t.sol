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

    /// @notice Property: withdraw-sender-rcv
    function check_withdraw_sender_rcv(
        address caller,
        uint256 depositAmount,
        uint256 withdrawAmount
    ) public {
        vm.assume(caller != address(0) && caller != address(bank));
    
        vm.assume(depositAmount <= 1000 ether);
        vm.assume(withdrawAmount <= 1000 ether);
        vm.deal(caller, 2000 ether);

        // Deposit
        vm.prank(caller);
        address(bank).call{value: depositAmount}(
            abi.encodeWithSelector(Bank.deposit.selector)
        );

        uint256 balanceBefore = caller.balance;

        // Withdraw
        vm.prank(caller);
        (bool success,) = address(bank).call(
            abi.encodeWithSelector(Bank.withdraw.selector, withdrawAmount)
        );

        if (success) {
            uint256 balanceAfter = caller.balance;
            assert(balanceAfter == balanceBefore + withdrawAmount);
        }
    }
}