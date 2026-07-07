// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "target/ExternalCallConstructor_v1.sol";

// CREAZIONE CHEATCODES HALMOS
// Definiamo un'interfaccia minimale con i soli cheatcode necessari ad Halmos
interface IHalmosVM {
    function etch(address target, bytes calldata runtimeBytecode) external;
    function load(address target, bytes32 slot) external view returns (bytes32);
}




contract ExternalCallConstructorTest {
    ExternalCallConstructor target;
    
    // L'indirizzo standard dei cheatcode di Foundry/Halmos
    IHalmosVM constant vm = IHalmosVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        // Creiamo un'istanza di State 
        State realState = new State();
        bytes memory stateBytecode = address(realState).code;

        vm.etch(address(0), stateBytecode);

        target = new ExternalCallConstructor();
    }

    /// Verifica la proprietà z-equals-2
    function check_z_equals_2() public view {
        // Accediamo allo storage del target usando il cheatcode vm.load() 
        // Lo slot 1 corrisponde alla variabile 'z'.
        bytes32 zValueBytes = vm.load(address(target), bytes32(uint256(1)));
        uint256 zAttuale = uint256(zValueBytes);

        // Se z è uguale a 2, il test passa.
        assert(zAttuale == 2);
    }
}