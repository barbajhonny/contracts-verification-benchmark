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

    function setUp() public {
        {{CONSTRUCTOR_SETUP}};
    }

    // Helper function to read credits directly from EVM storage
    function getCredits(address user) internal view returns (uint256) {
        bytes32 slot = keccak256(abi.encodePacked(user, uint256(0)));
        bytes32 value = vm.load(address(bank), slot);
        return uint256(value);
    }

    /// @notice Property: deposit-revert
    function check_deposit_revert(address caller, uint256 depositAmount) public {
        vm.assume(caller != address(0) && caller != address(bank));
        vm.assume(depositAmount > 1000); 

        vm.deal(caller, type(uint128).max); 
        
        vm.prank(caller);
        bank.deposit{value: type(uint128).max - 500}();

       vm.prank(caller);
        (bool success, ) = address(bank).call{value: depositAmount}(
            abi.encodeWithSelector(Bank.deposit.selector)
        );
        assert(!success);
    
    }
}