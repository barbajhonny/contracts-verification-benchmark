// SPDX-License-Identifier: UNLICENSED
pragma solidity >= 0.8.2;

import "target/{{VERSION}}.sol";

// Interfaccia standard per i cheatcode di Foundry/Halmos
interface Vm {
    function deal(address account, uint256 newBalance) external;
    function prank(address sender) external;
}

contract BankTest {
    // Istanziamo la VM all'indirizzo standard di Foundry
    Vm constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    
    // Dichiariamo il contratto della banca (usando il segnaposto)
    Bank bank;

    function check_assets_dec_onlyif_deposit(address owner) public {
        // Evitiamo che l'owner sia l'indirizzo zero o il contratto stesso per non sballare i test
        require(owner != address(0));
        require(owner != address(this));
        require(owner != address(bank));

        // Inizializziamo il contratto bancario specifico per questa esecuzione
        bank = new Bank();

        // Prepariamo i saldi simbolici
        vm.deal(owner, 4);
        vm.deal(address(this), 2);

        // Eseguiamo il deposito come "owner" nel contratto bank
        vm.prank(owner);
        bank.deposit{value: 1}();

        uint256 balance_before = owner.balance;

        // Eseguiamo il withdraw come "owner" nel contratto bank
        vm.prank(owner);
        bank.withdraw(1);

        uint256 balance_after = owner.balance;

        // Proprietà: il saldo dell'owner non deve essere diminuito dopo il withdraw
        assert(balance_after >= balance_before);
    }
}