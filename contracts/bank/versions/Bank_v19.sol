//SPDX-License-Identifier: UNLICENSED
pragma solidity >= 0.8.2;

/// @custom:version minimal implementation according to informal specification

contract Bank {
    mapping (address user => uint credit) credits;

    uint256 n = 0;
    function deposit( ) public payable {
        n += 1;
    
    }
    

    function withdraw(uint amount) public {
        require(amount > 0);
        require(amount <= credits[msg.sender]);

        credits[msg.sender] -= amount;

        (bool success,) = msg.sender.call{value: amount}("");
        require(success);
    }
}
