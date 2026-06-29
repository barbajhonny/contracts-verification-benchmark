pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {AssemblyAssignment} from "target/AssemblyAssignment_v1.sol"; 

contract AssemblyAssignmentTest is Test {
    AssemblyAssignment public target;

    // Inizializzi il contratto prima del test
    function setUp() public {
        target = new AssemblyAssignment();
    }

    // Il test simbolico vero e proprio per Halmos
    function check_AssemblyLogic(uint x) public view {
        // Chiediamo ad Halmos di verificare matematicamente l'output
        assert(target.f(x) == 2);
    }
}