// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "target/ExternalAbstract_v1.sol";
import "forge-std/Test.sol";

/// @notice Rappresenta un'implementazione arbitraria/non fidata di `D`.
/// Nel modello di verifica, un external call verso un contratto astratto
/// può fare "qualsiasi cosa" prima di ritornare: qui modelliamo il worst
/// case concreto, cioè un reentrant call a `f()`.
contract Attacker is D {
    ExternalAbstract public target;

    constructor(ExternalAbstract _target) {
        target = _target;
    }

    function d() external override {
        target.f();
    }
}

contract ExternalAbstractReentrancyTest is Test {
    ExternalAbstract target;
    Attacker attacker;

    // Storage layout di ExternalAbstract: slot0 = x (uint256, slot pieno),
    // slot1 = d (address, 20 byte). Verificare con
    // `forge inspect ExternalAbstract storage-layout` se il layout cambia.
    uint256 constant X_SLOT = 0;
    uint256 constant D_SLOT = 1;

    function setUp() public {
        target = new ExternalAbstract();
        attacker = new Attacker(target);
        // colleghiamo target.d al nostro contratto "malevolo"
        vm.store(
            address(target),
            bytes32(D_SLOT),
            bytes32(uint256(uint160(address(attacker))))
        );
    }

    /// Proprietà sotto verifica (equivalente all'assert/rule di
    /// Certora/SolCMC per questo caso): x deve restare < 10 in ogni
    /// momento, anche attraversando la external call fatta da g().
    ///
    /// Halmos deve trovare un controesempio con x0 == 9:
    /// g() supera il require(x<10), poi la external call reentra in
    /// f(), portando x a 10 PRIMA che g() ritorni.
    function check_x_abstract_call(uint256 x0) public {
        vm.assume(x0 < 10);
        vm.store(address(target), bytes32(X_SLOT), bytes32(x0));

        target.g();

        assert(target.getX() < 10); // <-- violato quando x0 == 9
    }
}