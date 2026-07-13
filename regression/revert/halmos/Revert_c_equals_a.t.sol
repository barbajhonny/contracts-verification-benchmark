// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "target/Revert_v1.sol";

contract RevertTest is Revert{

    function check_c_equals_a(bool b, uint256 a) public{

        f(b,a);

        assert(c == a);
    }

}