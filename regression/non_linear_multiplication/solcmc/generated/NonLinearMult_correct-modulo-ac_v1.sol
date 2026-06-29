// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract NonLinearMult {
    uint public constant c = 3;
    uint public  a;
    uint public  b;
    constructor(uint _a) {
        a = _a;
        b = c;
    }

    function getAB() public view returns (uint){
        return a * b;
    }
     
    function getAC() public view returns (uint) {
        return a * c;
    }

    function get_c() public pure returns (uint) {
    return c;
    }
    function get_a() public view returns (uint) {
    return a;
    }
    function get_b() public view returns (uint) {
    return b;
    }
    function invariant() public view {
        assert(getAC() % 3 == 0);
    }

}



