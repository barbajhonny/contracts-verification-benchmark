// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "target/CallVerifier_v1.sol";
import "forge-std/Test.sol";

contract CallVerifierTest is Test {
    CallVerifier cv;

    function setUp() public {
        cv = new CallVerifier();
    }

    // Proprietà 2: call-success (ground-truth = 0)
    function check_call_success(address a) public {
        cv.f(a);
        bool success = vm.load(address(cv), bytes32(uint256(1))) != bytes32(0); 
        assert(success == true);
    }

}