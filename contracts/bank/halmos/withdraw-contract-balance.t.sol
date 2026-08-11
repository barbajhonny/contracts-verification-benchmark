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

    /// @notice Property: withdraw-contract-balance
    function check_withdraw_contract_balance(
        address caller,
        uint256 depositAmount,
        uint256 withdrawAmount
    ) public {
        vm.assume(caller != address(0) && caller != address(bank));
        
        vm.assume(depositAmount > 0 && depositAmount <= 1000 ether);
        vm.assume(withdrawAmount > 0 && withdrawAmount <= depositAmount);
        
        vm.deal(caller, 2000 ether);
        
        vm.prank(caller);
        bank.deposit{value: depositAmount}();
        
        uint256 bankBalanceBefore = address(bank).balance;
        
        bool reverted = false;
        try bank.withdraw(withdrawAmount) {
            // Success
        } catch {
            reverted = true;
        }
        
        if (!reverted) {
            uint256 bankBalanceAfter = address(bank).balance;
            assert(bankBalanceBefore - bankBalanceAfter == withdrawAmount);
        }
    }
}