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
    function check_deposit_revert(
        address caller,
        uint256 depositAmount
    ) public {
        vm.assume(caller != address(0));
        vm.assume(caller != address(bank));

        vm.assume(depositAmount > 0 && depositAmount <= 100 ether);
        vm.deal(caller, type(uint256).max);

        uint256 currentCredits = getCredits(caller);

        bool willOverflow = (currentCredits + depositAmount < currentCredits);

        vm.prank(caller);
        
        if (willOverflow) {
            try bank.deposit{value: depositAmount}() {
                assert(false);
            } catch {
                assert(true);
            }
        } else {}
    }
}