// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.2;

import {Test} from "forge-std/Test.sol";
import {Bank} from "versions/Bank_v13.sol";

// Owner of Bank (halmos_owner_address = 0xaaaa0004 = userContract0 in the counterexample).
// receive_choice = 0 => accepts ETH and does nothing.
contract Owner {
    receive() external payable {}
}

// Contract user (userContract1 = 0xaaaa0005 in the counterexample), the depositor.
contract User {}

// Halmos counterexample (log: v13_deposit-contract-balance.log):
//   halmos_owner_address = 0xaaaa0004 (userContract0)
//   tx1: sender = userContract1 (sender_is_contract = 1, sender_is_contract0 = 0)
//        deposit()     p_value = 0x100000000000000000000000000000000
//        the `transfer(1)` to the owner triggers its receive: receive_choice = 0
// The bug: `deposit` forwards 1 wei of msg.value to the owner, so the Bank balance
// increases by msg.value - 1. Same scenario as forge/test/deposit-contract-balance_v13.t.sol
// (there the owner is an EOA and msg.value = 2 wei).
contract PoC_DepositContractBalance_v13 is Test {

    Bank bank;
    Owner owner;
    User user;

    function setUp() public {
        owner = new Owner();
        vm.prank(address(owner));
        bank = new Bank();
        user = new User();
    }

    function test_poc_deposit_contract_balance() public {
        uint256 value = 0x100000000000000000000000000000000;
        vm.deal(address(user), value);

        uint256 bankBefore = address(bank).balance;

        vm.prank(address(user));
        (bool ok,) = address(bank).call{value: value}(abi.encodeWithSignature("deposit()"));
        assertTrue(ok, "deposit() reverted: counterexample not reproduced");

        uint256 bankAfter = address(bank).balance;

        // property: after a non-reverting deposit, the Bank balance increases by msg.value
        assertNotEq(bankAfter - bankBefore, value, "deposit-contract-balance holds: counterexample not reproduced");
    }
}
