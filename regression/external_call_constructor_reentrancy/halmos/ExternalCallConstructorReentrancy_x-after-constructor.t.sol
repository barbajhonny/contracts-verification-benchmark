// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "target/ExternalCallConstructorReentrancy_v1.sol";

interface IHalmosVM {
    function load(address target, bytes32 slot) external view returns (bytes32);
}

contract InterfaceD is D {
    function ext(ExternalCallConstructorReentrancy c) external override returns (uint) {}
}

contract ExternalCallConstructorReentrancyTest {
    ExternalCallConstructorReentrancy target;
    InterfaceD interfaceD;

    IHalmosVM constant vm = IHalmosVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function check_x_after_constructor() public {

        interfaceD = new InterfaceD();

        target = new ExternalCallConstructorReentrancy(interfaceD);

        bytes32 xValueBytes = vm.load(address(target), bytes32(uint256(0)));
        uint256 xAttuale = uint256(xValueBytes);

        assert(xAttuale == 0);
    }
}