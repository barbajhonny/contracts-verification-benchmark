// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "target/NonLinearMult_v1.sol";

contract NonLinearMult_ab_eq_ac_Test {
    
    function check_ab_eq_ac(uint _a) public {
        NonLinearMult target = new NonLinearMult(_a);

        assert(target.getAB() == target.getAC());
    }
}
