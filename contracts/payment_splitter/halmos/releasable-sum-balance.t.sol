// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.2;

import "target/{{VERSION}}.sol";

interface IHalmosVM {
    function assume(bool condition) external;
    function prank(address msgSender) external;
    function deal(address account, uint256 newBalance) external;
}

contract PaymentSplitterTest {

    IHalmosVM constant vm = IHalmosVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    /// @notice Property: releasable-sum-balance
    function check_releasable_sum_balance(
        address payee1,
        uint256 shares1,
        address payee2,
        uint256 shares2,
        address payee3,
        uint256 shares3,
        uint256 initialFunding,
        uint256 additionalFunding
    ) public {
        // Tight Assumptions to prevent SMT solver explosion and WSL crash 
        vm.assume(payee1 != address(0));
        vm.assume(payee2 != address(0));
        vm.assume(payee3 != address(0));
        vm.assume(payee1 != payee2 && payee1 != payee3 && payee2 != payee3);

        uint256 totalExpectedShares = shares1 + shares2 + shares3;
        vm.assume(totalExpectedShares > 0);

        vm.assume(initialFunding <= 100000);
        vm.assume(additionalFunding <= 100000);

        {{CONSTRUCTOR_SETUP}};

        if (additionalFunding > 0) {
            vm.deal(address(this), additionalFunding);
            (bool success, ) = address(splitter).call{value: additionalFunding}("");
            vm.assume(success);
        }

        uint256 length = splitter.getPayeesLength();
        uint256 totalReleasableSum = 0;

        for (uint256 i = 0; i < length; i++) {
            address a = splitter.getPayee(i);
            totalReleasableSum += splitter.releasable(a);
        }

        uint256 contractBalance = address(splitter).balance;

        assert(totalReleasableSum == contractBalance);
    }
}