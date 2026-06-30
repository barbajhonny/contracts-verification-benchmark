pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {AssemblyAssignment} from "target/AssemblyAssignment_v1.sol"; 

contract AssemblyAssignmentTest is Test {
    AssemblyAssignment public target;

    //inizializazzione del contratto
    function setUp() public {
        target = new AssemblyAssignment();
    }

    function check_AssemblyLogic(uint x) public view {

        assert(target.f(x) == 2);
    }
}