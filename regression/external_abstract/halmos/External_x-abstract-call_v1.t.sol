// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "target/ExternalAbstract_v1.sol";
import "forge-std/Test.sol";

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