// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "target/NonLinearMult_v1.sol";

contract NonLinearMult_correct_modulo_ac_Test {

    function check_correct_modulo_ac(uint _a) public {
        NonLinearMult target = new NonLinearMult(_a);

        assert(target.getAC() % 3 == 0);
    }
}