// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import"target/MutexSafe_v1.sol";

contract MutexSafeTest is MutexSafe{

    function check_check_mutex(address attacker) public{

        set(10);
        f(attacker);
        assert(getX()==10);

    }

}