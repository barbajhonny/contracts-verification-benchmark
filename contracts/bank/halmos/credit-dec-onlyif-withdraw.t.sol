// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.2;

import "target/{{VERSION}}.sol";
import "./BankHandler/bankHandler.sol";
import {SymTest} from "halmos-cheatcodes/SymTest.sol";


contract BankTest is SymTest {
    IHalmosVM constant vm = IHalmosVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    Bank bank;
    BankHandler handler;

    function setUp() public {
        bank = new Bank();
        handler = new BankHandler(address(bank));
        uint256 handlerBalance = svm.createUint256("handlerBalance");
        vm.deal(address(handler), handlerBalance);
    }

    function creditsSlot(address user) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(uint256(uint160(user)), uint256(0)));
    }

    function getCredits(address user) internal view returns (uint256) {
        return uint256(vm.load(address(bank), creditsSlot(user)));
    }

    /// @custom:halmos --invariant-depth 3
    function invariant_credit_dec_onlyif_withdraw() public view {
        if (!handler.hasOperated()) return;

        address caller = handler.lastCaller();
        uint256 before = handler.lastCreditsBefore();
        uint256 afterBal = getCredits(caller);

        if (afterBal < before) {
            assert(handler.lastWasWithdraw());
        }
    }
}