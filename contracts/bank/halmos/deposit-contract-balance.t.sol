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

    /// @notice Property: deposit-contract-balance
    function check_deposit_contract_balance(
        address caller,
        uint256 depositAmount,
        uint256 initialBalance
    ) public {
        vm.assume(caller != address(0));
        vm.assume(caller != address(bank));

        vm.assume(depositAmount > 0 && depositAmount <= 100 ether);
        vm.assume(initialBalance >= depositAmount);
        vm.assume(initialBalance <= 1000 ether);

        vm.deal(caller, initialBalance);

        uint256 bankEthBefore = address(bank).balance;

        vm.prank(caller);
        
        bank.deposit{value: depositAmount}();

        uint256 bankEthAfter = address(bank).balance;
        
        assert(bankEthAfter == bankEthBefore + depositAmount);
    }
}