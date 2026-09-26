// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "target/TwoModifiers_v1.sol";

contract TwoModifiersTest is TwoModifiers {

    function check_g_modifiers_x_right() public {
        g();
        
        assert(x == 7);
    }

}