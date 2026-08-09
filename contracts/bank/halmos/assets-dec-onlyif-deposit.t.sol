// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.2;

import "target/{{VERSION}}.sol";

interface IHalmosVM {
    function assume(bool condition) external;
    function prank(address msgSender) external;
    function deal(address account, uint256 newBalance) external;
}

// Auxiliary contract that simulates a user Smart Contract with callbacks
contract ContractUser {
    Bank bank;
    address destination;

    constructor(Bank _bank, address _destination) {
        bank = _bank;
        destination = _destination;
    }

    function deposit(uint256 amount) external payable {
        bank.deposit{value: amount}();
    }

    function withdraw(uint256 amount) external {
        bank.withdraw(amount);
    }

    // When Bank.withdraw() sends ETH to this contract, the callback is executed
    // and empties the contract balance by sending the funds to another destination.
    receive() external payable {
        if (destination != address(0)) {
            payable(destination).transfer(address(this).balance);
        }
    }
}

contract BankTest {
    IHalmosVM constant vm = IHalmosVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    Bank bank;

    function setUp() public {
        {{CONSTRUCTOR_SETUP}};
    }

    /// @notice Property: assets-dec-onlyif-deposit
    function check_assets_dec_onlyif_deposit(
        bool isDeposit,
        uint256 amount,
        address burnTarget,
        uint256 extraBalance
    ) public {
        vm.assume(burnTarget != address(0));
        vm.assume(amount > 0 && amount <= 100 ether);
        vm.assume(extraBalance <= 100 ether);

        ContractUser userA = new ContractUser(bank, burnTarget);
        vm.deal(address(userA), amount + extraBalance);

        if (!isDeposit) {
            userA.deposit{value: amount}(amount);
        }

        uint256 balanceBefore = address(userA).balance;

        if (isDeposit) {
            try userA.deposit{value: amount}(amount) {} catch {}
        } else {
            try userA.withdraw(amount) {} catch {}
        }

        uint256 balanceAfter = address(userA).balance;

        if (balanceAfter < balanceBefore) {
            assert(isDeposit);
        }
    }
}