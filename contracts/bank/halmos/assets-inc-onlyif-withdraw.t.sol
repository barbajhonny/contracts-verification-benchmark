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

    function check_assets_inc_onlyif_withdraw_solcmc_style(
        bool isWithdraw,
        uint256 amount,
        address caller,
        address targetUser,
        uint256 initialBalance
    ) public {

        vm.assume(caller != address(0));
        vm.assume(targetUser != address(0));
        vm.assume(amount > 0 && amount <= 100 ether);
        vm.assume(initialBalance <= 200 ether);

        // Give initial funds into the wallet
        vm.deal(caller, initialBalance);
        vm.deal(targetUser, initialBalance);

        if (isWithdraw) {
            vm.prank(caller);
            bank.deposit{value: amount}();
        }

        // Initial balance
        uint256 currb = targetUser.balance;

        vm.prank(caller);
        if (isWithdraw) {
            try bank.withdraw(amount) {} catch {}
        } else {
            try bank.deposit{value: amount}() {} catch {}
        }

        // Final balance 
        uint256 newb = targetUser.balance;

        if (newb > currb) {
            assert(isWithdraw);
            assert(caller == targetUser);
        }
    }
}