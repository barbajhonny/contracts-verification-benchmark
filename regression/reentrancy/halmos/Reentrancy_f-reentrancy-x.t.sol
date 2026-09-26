// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "target/Reentrancy_v1.sol";

contract Attacker {
    fallback() external payable {
        (bool success, ) = msg.sender.call(abi.encodeWithSignature("s(uint256)", 999));
        require(success);
    }
}

contract ReentrancyTest is Reentrancy {
    function check_f_reentrancy_x() public {
        
        s(0);

        Attacker attacker = new Attacker();

        f(address(attacker));

        assert(x == 0);
    }
}