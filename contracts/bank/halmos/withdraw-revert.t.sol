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

    /// @notice Property: withdraw-revert
     function check_withdraw_revert(
        address caller,
        uint256 depositAmount,
        uint256 withdrawAmount
    ) public {
        vm.assume(caller != address(0));
        vm.assume(caller != address(bank));
        vm.assume(caller != address(vm));

        vm.assume(depositAmount <= 1000 ether);
        vm.assume(withdrawAmount <= 1000 ether);
        vm.deal(caller, 2000 ether);

        vm.prank(caller);
        (bool depositSuccess,) = address(bank).call{value: depositAmount}(
            abi.encodeWithSelector(Bank.deposit.selector)
        );

        uint256 credit = getCredits(caller);
        bool shouldRevert = (withdrawAmount == 0 || withdrawAmount > credit);

        vm.prank(caller);
        (bool success,) = address(bank).call(
            abi.encodeWithSelector(Bank.withdraw.selector, withdrawAmount)
        );

        if (shouldRevert) {
            assert(!success);
        }
    }
}