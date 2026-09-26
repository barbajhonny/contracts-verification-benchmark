// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "target/C_v1.sol";

contract CTest is C {
    function check_foo() public view {
        // Chiamiamo la funzione f() come descritto dalla proprietà
        f();

        // Verifichiamo la proprietà "foo": il bilancio del contratto non è zero
        assert(address(this).balance > 0);
    }
}