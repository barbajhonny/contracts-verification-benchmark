// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "target/MutexUnsafe_v1.sol";

contract MutexUnsafeTest is MutexUnsafe {

    function check_check_mutex() public {
        set(10);

        // Passiamo l'indirizzo di questo contratto stesso come "attaccante"
        f(address(this));

        assert(getX() == 10);
    }

    // Questa funzione intercetta la chiamata _a.call("aaaaa") inviata a address(this)
    fallback() external payable {
        // Reentrancy nella funzione set modificando il valore
        set(999);
    }
}