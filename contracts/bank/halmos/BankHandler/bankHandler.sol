// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.2;

/// @notice Interfaccia minima per le cheatcode di Halmos/Foundry usate dall'Handler
interface IHalmosVM {
    function load(address account, bytes32 slot) external view returns (bytes32);
    function deal(address account, uint256 newBalance) external;
}

/// @notice Handler per la proprietà credit-dec-onlyif-withdraw.
/// Viene usato da Halmos come contratto target per esplorare automaticamente
/// sequenze di chiamate a deposit/withdraw. Traccia l'ultima operazione eseguita
/// (chi l'ha chiamata, quanto era il credito prima, se era un withdraw) per
/// permettere all'invariante di verificare la proprietà.
///
/// Nota: questo Handler NON importa Bank. Riceve l'indirizzo nel costruttore
/// e usa chiamate a basso livello, così è compatibile con tutte le 17 versioni
/// di Bank senza bisogno di sostituzioni {{VERSION}}.
contract BankHandler {
    IHalmosVM constant vm = IHalmosVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    address public bank;

    // Stato tracciato per l'ultima operazione
    address public lastCaller;
    uint256 public lastCreditsBefore;
    bool public lastWasWithdraw;
    bool public hasOperated;

    constructor(address _bank) {
        bank = _bank;
    }

    // --- Utilità per leggere lo slot credits ---
    // Assunzione: credits è sempre allo slot 0 in tutte le versioni di Bank
    function creditsSlot(address user) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(uint256(uint160(user)), uint256(0)));
    }

    function getCredits(address user) internal view returns (uint256) {
        return uint256(vm.load(bank, creditsSlot(user)));
    }

    // --- Funzioni target scoperte automaticamente da Halmos ---

    /// @notice Wrapper per deposit(). Registra lo stato prima della chiamata.
    function deposit(uint256 amount) public payable {
        // Normalizza amount per evitare overflow e valori nulli
        amount = amount % 1 ether;
        if (amount == 0) amount = 1;

        // Registra lo stato dell'ultima operazione
        lastCaller = msg.sender;
        lastCreditsBefore = getCredits(msg.sender);
        lastWasWithdraw = false;
        hasOperated = true;

        // Inoltra la chiamata a Bank.deposit() passando msg.value = amount
        (bool ok,) = bank.call{value: amount}(
            abi.encodeWithSignature("deposit()")
        );
        // Se la chiamata fallisce (es. per una versione con firma diversa),
        // lo stato di Bank non cambia e l'invariante non viene violato.
        ok;
    }

    /// @notice Wrapper per withdraw(uint). Registra lo stato prima della chiamata.
    function withdraw(uint256 amount) public {
        // Normalizza amount
        amount = amount % 1 ether;
        if (amount == 0) amount = 1;

        // Registra lo stato dell'ultima operazione
        lastCaller = msg.sender;
        lastCreditsBefore = getCredits(msg.sender);
        lastWasWithdraw = true;
        hasOperated = true;

        // Inoltra la chiamata a Bank.withdraw(uint)
        (bool ok,) = bank.call(
            abi.encodeWithSignature("withdraw(uint256)", amount)
        );
        ok;
    }

    /// @notice Riceve fondi per poter effettuare deposit con msg.value
    receive() external payable {}
}