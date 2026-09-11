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

    /// @notice Property: release-not-revert
    /// For all addresses `a` in `payees`, if `releasable(a) > 0`, then `release(a)` does not revert.
    function check_release_not_revert(
        address payee1,
        uint256 shares1,
        address payee2,
        uint256 shares2,
        address payee3,
        uint256 shares3,
        uint256 initialFunding,
        uint256 additionalFunding,
        uint256 targetIndex
    ) public {
        vm.assume(payee1 != address(0));
        vm.assume(payee2 != address(0));
        vm.assume(payee3 != address(0));
        vm.assume(payee1 != payee2 && payee1 != payee3 && payee2 != payee3);

        uint256 totalExpectedShares = shares1 + shares2 + shares3;
        vm.assume(totalExpectedShares > 0 && totalExpectedShares <= 30);

        vm.assume(initialFunding <= 10000);
        vm.assume(additionalFunding <= 10000);

        {{CONSTRUCTOR_SETUP}};

        if (additionalFunding > 0) {
            vm.deal(address(this), additionalFunding);
            (bool success, ) = address(splitter).call{value: additionalFunding}("");
            vm.assume(success);
        }

        vm.assume(targetIndex < 3);

        address a;
        if (targetIndex == 0) {
            a = payee1;
        } else if (targetIndex == 1) {
            a = payee2;
        } else {
            a = payee3;
        }

        uint256 releasableAmount = splitter.releasable(payable(a));

        if (releasableAmount > 0) {
            try splitter.release(payable(a)) {
            } catch {
                assert(false);
            }
        }
    }
}