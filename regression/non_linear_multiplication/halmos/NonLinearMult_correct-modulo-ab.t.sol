// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "target/NonLinearMult_v1.sol";

contract NonLinearMult_correct_modulo_ab_Test {

    function check_correct_modulo_ab(uint _a) public {
        NonLinearMult target = new NonLinearMult(_a);

        assert(target.getAB() % 3 == 0);
    }
}