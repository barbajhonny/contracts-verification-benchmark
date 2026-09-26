// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "target/ThisPayable_v1.sol";

interface IHalmosVM {
    function deal(address account, uint256 newBalance) external;
}

contract ThisPayableTest is ThisPayable {

    IHalmosVM constant vm = IHalmosVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function check_g_check_balance(uint256 i) public {

        vm.deal(address(this), 100);

        uint256 balanceBefore = address(this).balance;

        g(i);

        assert(address(this).balance == balanceBefore);
    }
}