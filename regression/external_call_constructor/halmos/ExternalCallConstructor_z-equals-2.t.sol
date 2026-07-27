// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "target/ExternalCallConstructor_v1.sol";

// Cheatcodes Halmos
interface IHalmosVM {
    function etch(address target, bytes calldata runtimeBytecode) external;
    function load(address target, bytes32 slot) external view returns (bytes32);
}


contract ExternalCallConstructorTest {
    ExternalCallConstructor target;
    
    // The standard address for Halmos cheatcodes
    IHalmosVM constant vm = IHalmosVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        State realState = new State();
        bytes memory stateBytecode = address(realState).code;

        vm.etch(address(0), stateBytecode);

        target = new ExternalCallConstructor();
    }

    function check_z_equals_2() public view {
    
        // Slot 1 corresponds to variable 'z'.
        bytes32 zValueBytes = vm.load(address(target), bytes32(uint256(1)));
        uint256 zAttuale = uint256(zValueBytes);

        assert(zAttuale == 2);
    }
}