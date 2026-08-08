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

    
    function check_credit_dec_onlyif_withdraw(
        bool isWithdraw, 
        uint256 amount,
        address caller,  
        address targetUser,
        uint256 initialBalance
    ) public {
        vm.assume(caller != address(0));
        vm.assume(targetUser != address(0));
        vm.assume(amount > 0 && amount <= 50 ether);
        vm.assume(initialBalance <= 100 ether);

        vm.deal(caller, initialBalance);
        vm.deal(targetUser, initialBalance);

        // Give initial credits to targetUser by making a deposit
        vm.prank(targetUser);
        try bank.deposit{value: 10 ether}() {} catch {}

        uint256 currb = getCredits(targetUser);

        vm.prank(caller);
        if (isWithdraw) {
            try bank.withdraw(amount) {} catch {}
        } else {
            try bank.deposit{value: amount}() {} catch {}
        }

        uint256 newb = getCredits(targetUser);

        if (newb < currb) {
            assert(isWithdraw);
            assert(caller == targetUser);
        }
        
    }
}