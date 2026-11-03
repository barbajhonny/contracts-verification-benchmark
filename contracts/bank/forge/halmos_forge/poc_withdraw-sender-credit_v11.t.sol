// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.2;

import {Test} from "forge-std/Test.sol";
import {Bank} from "versions/Bank_v11.sol";

// Contract user (userContract1 = 0xaaaa0005 in the counterexample).
// Mirrors BankUser: reacts at most once per transaction (`reacted`), and the reaction
// chosen by Halmos is receive_choice = 2, receive_peer_acts = false:
// the user itself calls Bank with `reentryData` and value `reentryValue`, ignoring the outcome.
contract User {
    Bank immutable bank;
    bool public reacted;
    bytes public reentryData;
    uint256 public reentryValue;

    constructor(Bank _bank) { bank = _bank; }

    function newTransaction() external { reacted = false; }

    function setReentry(bytes calldata data, uint256 value) external {
        reentryData = data;
        reentryValue = value;
    }

    receive() external payable {
        if (reacted) return;
        reacted = true;
        if (reentryData.length == 0) return; // receive_choice = 0
        (bool ok,) = address(bank).call{value: reentryValue}(reentryData);
        ok; // the outcome is irrelevant, as in BankUser.act
    }
}

// Halmos counterexample (log: v11_withdraw-sender-credit.log):
//   halmos_owner_address = 0x8000000000000000000000000000000000000000
//   tx1: sender = userContract1, deposit()   p_value  = 0x100000000000000000000000000000000
//   tx2: sender = userContract1, withdraw(p_amount)  p_amount = 0x80000000000000000000000000000000
//        the low-level call in `withdraw` calls the receive of userContract1:
//        receive_choice = 2, receive_peer_acts = 0, receive_call_value = 0,
//        calldata = withdraw(1)  (p_amount = 0x01)
// The bug: `withdraw` is reentrant, so the sender's credit decreases by amount + 1.
// The pause flag of v11 is never set (owner never calls setP).
contract PoC_WithdrawSenderCredit_v11 is Test {

    Bank bank;
    User user;
    address constant OWNER = 0x8000000000000000000000000000000000000000;

    function setUp() public {
        vm.prank(OWNER);
        bank = new Bank();
        user = new User(bank);
    }

    function _credits(address who) internal view returns (uint256) {
        return uint256(vm.load(address(bank), keccak256(abi.encode(who, uint256(0)))));
    }

    function test_poc_withdraw_sender_credit() public {
        uint256 value = 0x100000000000000000000000000000000;
        uint256 amount = 0x80000000000000000000000000000000;

        // tx1: userContract1 deposits
        user.newTransaction();
        vm.deal(address(user), value);
        vm.prank(address(user));
        bank.deposit{value: value}();

        // tx2: userContract1 withdraws; its receive re-enters with withdraw(1)
        user.newTransaction();
        user.setReentry(abi.encodeWithSignature("withdraw(uint256)", uint256(1)), 0);
        uint256 creditBefore = _credits(address(user));

        vm.prank(address(user));
        (bool ok,) = address(bank).call(abi.encodeWithSignature("withdraw(uint256)", amount));
        assertTrue(ok, "withdraw reverted: counterexample not reproduced");

        uint256 creditAfter = _credits(address(user));

        // property: after a non-reverting withdraw(amount), the sender's credit decreases by amount
        assertNotEq(creditBefore - creditAfter, amount, "withdraw-sender-credit holds: counterexample not reproduced");
    }
}
