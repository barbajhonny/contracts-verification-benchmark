// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "target/ExternalCallConstructorReentrancy_v1.sol";

interface IHalmosVM {
    function load(address target, bytes32 slot) external view returns (bytes32);
}

// Implementazione standard dell'interfaccia di D  
contract InterfaceD is D {
    function ext(ExternalCallConstructorReentrancy c) external override returns (uint) {
        return 42; // Ritorna un valore qualsiasi, simulando il successo della chiamata
    }
}

contract ExternalCallConstructorReentrancyTest {
    ExternalCallConstructorReentrancy target;
    InterfaceD interfaceD;

    IHalmosVM constant vm = IHalmosVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function check_x_after_constructor() public {
        // 1. Creiamo il contratto esterno
        interfaceD = new InterfaceD();

        // 2. Eseguiamo il deploy del target.
        target = new ExternalCallConstructorReentrancy(interfaceD);

        // 3. Leggiamo lo storage slot 0 (la variabile x)
        bytes32 xValueBytes = vm.load(address(target), bytes32(uint256(0)));
        uint256 xAttuale = uint256(xValueBytes);

        assert(xAttuale == 0);
    }
}