// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "target/ReentrancyView_v1.sol";

contract Attacker {
    fallback() external payable {
        (bool success, ) = msg.sender.call(abi.encodeWithSignature("s(uint256)", 999));
        require(success);
    }
}

contract ReentrancyViewTest is ReentrancyView {
    function check_f_reentrancy_view_x() public {
        
        Attacker attacker = new Attacker();

        f(address(attacker));

        assert(x == 0);
    }
}