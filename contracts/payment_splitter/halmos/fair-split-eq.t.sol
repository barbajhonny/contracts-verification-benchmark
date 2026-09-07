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

    /// @notice Property: fair-split-eq
    function check_fair_split_eq(
        address payee1,
        uint256 shares1,
        address payee2,
        uint256 shares2,
        address payee3,
        uint256 shares3,
        uint256 initialFunding,
        uint256 additionalFunding
    ) public {
        vm.assume(payee1 != address(0));
        vm.assume(payee2 != address(0));
        vm.assume(payee3 != address(0));
        vm.assume(payee1 != payee2 && payee1 != payee3 && payee2 != payee3);
        vm.assume(shares1 < 10**30);
        vm.assume(shares2 < 10**30);
        vm.assume(shares3 < 10**30);
        vm.assume(initialFunding < 10**30);
        vm.assume(additionalFunding < 10**30);

        // Keep total shares within safe bounds to prevent arithmetic overflow in division/multiplication
        uint256 totalExpectedShares = shares1 + shares2 + shares3;
        vm.assume(totalExpectedShares > 0 && totalExpectedShares < 10**24);

        vm.assume(initialFunding < 10**24);
        vm.assume(additionalFunding < 10**24);

        {{CONSTRUCTOR_SETUP}};

        // Send additional ETH to the splitter to test accumulation of totalReceived
        if (additionalFunding > 0) {
            vm.deal(address(this), additionalFunding);
            (bool success, ) = address(splitter).call{value: additionalFunding}("");
            vm.assume(success);
        }

        address[3] memory payees = [payee1, payee2, payee3];

        for (uint256 i = 0; i < 3; i++) {
            address a = payees[i];

            uint256 releasedAmount = splitter.getReleased(a);
            uint256 releasableAmount = splitter.releasable(a);
            uint256 sharesAmount = splitter.getShares(a);
            
            uint256 totalReceived = address(splitter).balance + splitter.getSumOfReleased();
            uint256 totalShares = splitter.getTotalShares();

            assert(releasedAmount + releasableAmount == (totalReceived * sharesAmount) / totalShares);
        }
    }
}