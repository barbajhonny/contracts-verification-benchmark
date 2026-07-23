// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "target/{{VERSION}}.sol";

interface IHalmosVM {
    function assume(bool condition) external;
}

contract Sink {
    receive() external payable {}
}

contract BankTest {
    Bank public bank;
    Sink public sink;
    IHalmosVM constant vm = IHalmosVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        {{CONSTRUCTOR_SETUP}};
        sink = new Sink();
    }

    // Reentrancy: svuota il saldo nel sink
    receive() external payable {
        (bool success, ) = address(sink).call{value: address(this).balance}("");
    }

    function check_assets_dec_onlyif_deposit(uint256 amount, uint8 choice) public {
        vm.assume(amount > 0);
        vm.assume(amount < 100 ether);
        vm.assume(choice <= 1);

        uint256 oldBalance = address(this).balance;

        if (choice == 0) {
            bank.deposit{value: amount}();
        } else {
            bank.deposit{value: amount}();
            bank.withdraw(amount);
        }

        uint256 newBalance = address(this).balance;

        if (newBalance < oldBalance) {
            assert(choice == 0);
        }
    }
}