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

    /// @notice Property: non-zero-payees
    function check_non_zero_payees(
        address payee1,
        uint256 shares1,
        address payee2,
        uint256 shares2,
        address payee3,
        uint256 shares3,
        uint256 initialFunding
    ) public {
        vm.assume(shares1 > 0 && shares1 < 10**18);
        vm.assume(shares2 > 0 && shares2 < 10**18);
        vm.assume(shares3 > 0 && shares3 < 10**18);

        uint256 totalExpectedShares = shares1 + shares2 + shares3;
        vm.assume(totalExpectedShares > 0 && totalExpectedShares < 10**24);
        vm.assume(initialFunding < 10**24);

        {{CONSTRUCTOR_SETUP}};

        uint256 length = splitter.getPayeesLength();
        for (uint256 i = 0; i < length; i++) {
            address a = splitter.getPayee(i);
            assert(a != address(0));
        }
    }
}