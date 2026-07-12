// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "target/Payable_v1.sol";

interface VM {
    function deal(address account, uint256 newBalance) external;
}

contract PayableTest {
    Payable target;
    VM constant vm = VM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        target = new Payable();
        vm.deal(address(target), 100);
    }

    function check_g_check_balance(address payable i) public {
        target.g(i);
        assert(address(target).balance == 90);
    }
}