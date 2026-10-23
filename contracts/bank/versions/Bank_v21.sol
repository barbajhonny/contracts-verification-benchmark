//SPDX-License-Identifier: UNLICENSED
pragma solidity >= 0.8.2;

/// @custom:version scarica deposit; withdraw uses transfer (no low-level call, no reentrancy)

contract Bank {
    mapping (address user => uint credit) credits;

    function deposit() public payable {
        credits[msg.sender] += msg.value;
    }

    function withdraw(uint amount) public {
        require(amount > 0);
        require(amount <= credits[msg.sender]);

        credits[msg.sender] -= amount;

        payable(msg.sender).transfer(amount);
    }
}
