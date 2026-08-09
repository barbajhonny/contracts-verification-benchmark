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

    /// @notice Property: credit-inc-onlyif-deposit
    function check_credit_inc_onlyif_deposit(
        bool isDeposit,
        uint256 amount,
        address caller,
        address targetUser,
        uint256 initialBalance
    ) public {
        vm.assume(caller != address(0));
        vm.assume(targetUser != address(0));
        vm.assume(amount > 0 && amount <= 50 ether);
        vm.assume(initialBalance <= 100 ether);

        // Give ETH into the wallet
        vm.deal(caller, initialBalance);
        vm.deal(targetUser, initialBalance);

        // Record targetUser's credit
        uint256 currb = getCredits(targetUser);

        vm.prank(caller);
        if (isDeposit) {
            try bank.deposit{value: amount}() {} catch {}   
        } else {
            try bank.withdraw(amount) {} catch {}  
        }

        // Record targetUser's credits after the transaction
        uint256 newb = getCredits(targetUser);

        if (newb > currb) {
            assert(isDeposit);
            assert(caller == targetUser);
        }
    }
}