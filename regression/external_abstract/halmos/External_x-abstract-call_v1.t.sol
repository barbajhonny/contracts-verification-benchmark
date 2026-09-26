// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "target/ExternalAbstract_v1.sol";

interface IHalmosVM {
    function store(address target, bytes32 slot, bytes32 value) external;
    function assume(bool condition) external pure;
}

contract Attacker is D {
    ExternalAbstract public target;

    constructor(ExternalAbstract _target) {
        target = _target;
    }

    function d() external override {
        target.f();
    }
}

contract ExternalAbstractReentrancyTest {
    ExternalAbstract target;
    Attacker attacker;

    IHalmosVM constant vm = IHalmosVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    uint256 constant X_SLOT = 0;
    uint256 constant D_SLOT = 1;

    function check_x_abstract_call(uint256 x0) public {

        target = new ExternalAbstract();
        attacker = new Attacker(target);

        vm.store(
            address(target),
            bytes32(D_SLOT),
            bytes32(uint256(uint160(address(attacker))))
        );

        vm.assume(x0 < 10);
        vm.store(address(target), bytes32(X_SLOT), bytes32(x0));

        target.g();

        assert(target.getX() == x0);
    }
}