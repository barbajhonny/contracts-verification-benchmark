// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "target/CallVerifier_v1.sol";
import "forge-std/Test.sol";

contract CallVerifierTest is Test {
    CallVerifier cv;

    function setUp() public {
        cv = new CallVerifier();
    }

    // Proprietà 1: call-failure (ground-truth = 0)
    function check_call_failure(address a) public {
        cv.f(a);
        bool success = vm.load(address(cv), bytes32(uint256(1))) != bytes32(0);
        assert(success == false);
    }

}