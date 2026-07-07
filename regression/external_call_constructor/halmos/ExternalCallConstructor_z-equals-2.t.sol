// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "target/ExternalCallConstructor_v1.sol";
import "forge-std/Test.sol";

contract ExternalCallConstructorTest is Test {
   
    ExternalCallConstructor target;

    function setUp() public {
        // Piazziamo il codice di State all'indirizzo zero così il costruttore non fa revert
        vm.etch(address(0), type(State).runtimeCode);

        // Distribuiamo il contratto target
        target = new ExternalCallConstructor();
    }
    
    // Proprietà: z-equals-2 (ground truth = 1)
    function check_ZEqualsTwo() public view {
        // Poiché z non è public, non possiamo fare target.z(). 
        // Usiamo vm.load per leggere lo slot 1 dell'indirizzo del target, 
        // proprio come nel tuo esempio funzionante di CallVerifier!
        bytes32 val = vm.load(address(target), bytes32(uint256(1)));
        
        assert(uint256(val) == 2);
    }
}