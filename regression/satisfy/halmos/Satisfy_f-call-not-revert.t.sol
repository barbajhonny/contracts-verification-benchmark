// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "target/Satisfy_v1.sol";

contract SatisfyTest is Satisfy{

    function check_f_call_not_reverted(uint256 a, uint256 b, uint256 _r0, uint256 _r1) public {
        r0 = _r0;
        r1 = _r1;

        f(a,b);

        assert(false);
    }

}