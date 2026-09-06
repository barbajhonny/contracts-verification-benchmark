// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.2;

import "target/{{VERSION}}.sol";

interface IHalmosVM {
    function assume(bool condition) external;
    function prank(address msgSender) external;
    function deal(address account, uint256 newBalance) external;
    function roll(uint256 blockNumber) external;
}

contract PriceBetTest {

    IHalmosVM constant vm = IHalmosVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    /// @notice Property: owner-cannot-withdraw-before-deadline
    /// If the deadline has not passed yet, then the owner cannot fire a transaction
    /// to the PriceBet contract after which its ETH balance is increased.
    function check_owner_cannot_withdraw_before_deadline(
        uint256 initialPot,
        uint256 timeout,
        address player,
        uint256 blockJump,
        uint256 exchangeRate,
        uint256 oraclePrice
    ) public {
        vm.assume(initialPot > 0 && initialPot < 10**24);
        vm.assume(timeout > 0 && timeout < 1000000);
        vm.assume(exchangeRate > 0 && exchangeRate < 10**24);
        vm.assume(player != address(0));
        vm.assume(blockJump < timeout);

        address owner = address(this);
        uint256 deploymentBlock = block.number;

        // Setup oracle and PriceBet
        Oracle oracle = new Oracle(exchangeRate);
        vm.deal(owner, initialPot);
        PriceBet priceBet = new PriceBet{value: initialPot}(address(oracle), timeout, exchangeRate);

        // Player joins
        vm.deal(player, initialPot);
        vm.prank(player);
        try priceBet.join{value: initialPot}() {} catch {
            return;
        }

        // Advance time but stay before deadline
        if (blockJump > 0) {
            vm.roll(deploymentBlock + blockJump);
        }

        // Oracle may change price
        Oracle(address(oracle)).set_exchange_rate(oraclePrice);

        // Record owner balance before owner fires transaction
        uint256 ownerBalanceBefore = owner.balance;

        // Owner fires transactions (not any caller!)
        vm.prank(owner);

        // Test 1: owner calls timeout()
        try priceBet.timeout() {} catch {}

        // Test 2: owner calls win()
        try priceBet.win() {} catch {}

        // Test 3: owner calls join()
        vm.deal(owner, initialPot);
        try priceBet.join{value: initialPot}() {} catch {}

        // Property: owner balance must not increase after owner-fired tx
        assert(owner.balance == ownerBalanceBefore);
    }
}