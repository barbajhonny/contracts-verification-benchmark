// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "target/Storage_v1.sol";

contract StorageTest is Storage{

    function check_equivalent_operations_same_result (uint256 _initialX, uint256 n) public {

        x = _initialX;

        f(n);

        assert(x == sum(_initialX, n));

    }

}