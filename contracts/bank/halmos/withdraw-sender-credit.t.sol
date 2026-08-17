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

   function getCredits(address user) internal view returns (uint256) {
        bytes32 slot = keccak256(abi.encodePacked(uint256(uint160(user)), uint256(0)));
        bytes32 value = vm.load(address(bank), slot);
        return uint256(value);
    }

    /// @notice Property: withdraw-sender-credit
    function check_withdraw_sender_credit(
        address caller,
        uint256 depositAmount,
        uint256 withdrawAmount
    ) public {
        vm.assume(caller != address(0) && caller != address(bank));
        vm.assume(depositAmount > 0 && depositAmount <= 1000 ether);
        vm.assume(withdrawAmount > 0 && withdrawAmount <= 1000 ether);
        vm.assume(withdrawAmount <= depositAmount);
        
        vm.deal(caller, 2000 ether);
        
        vm.prank(caller);
        bank.deposit{value: depositAmount}();
        
        uint256 creditBefore = getCredits(caller);
        
        bool reverted;
        vm.prank(caller);
        try bank.withdraw(withdrawAmount) {
            // Not revert
        } catch {
            reverted = true;
        }
        
        if (!reverted) {
            uint256 creditAfter = getCredits(caller);
            assert(creditBefore - creditAfter == withdrawAmount);
        }
        
    }
}