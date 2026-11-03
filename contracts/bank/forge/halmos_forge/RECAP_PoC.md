# Recap: PoC Forge per i controesempi di Halmos (use case Bank)

## Contesto

Tesi triennale: integrazione di **Halmos 0.3.3** nel *Contracts Verification Benchmark*, use case **Bank** (`contracts/bank`).

Halmos verifica le proprietà con invariant testing, tramite `BankHandler`/`BankUser` in `contracts/bank/halmos/`. Quando trova una violazione restituisce **N!** con un controesempio. Gli altri esiti sono **P** (nessun controesempio) e **UNK** (timeout di 10 minuti).

**Obiettivo delle PoC:** controllare se i controesempi di Halmos si possono eseguire davvero sulla EVM reale (Forge/revm). È prevista almeno una PoC per ogni versione (v1–v17).

Convenzioni della ground truth (`ground-truth.csv`): `truth = 0` vuol dire proprietà violata, `truth = 1` proprietà valida.

## Struttura e setup

Cartella: `contracts/bank/forge/halmos_forge/`.

`foundry.toml`:
```toml
[profile.default]
src = '.'
test = '.'
out = 'out'
libs = ['../../../../lib']
allow_paths = ['../../versions']
skip = []

remappings = [
    'versions/=../../versions/'
]

[lint]
lint_on_build = false
```

Altre modifiche:
- È stato creato `contracts/bank/versions/lib/ReentrancyGuard.sol`, una copia di `lib/ReentrancyGuard.sol`. Serve perché v8 e v9 fanno `import "./lib/ReentrancyGuard.sol"`.
- In `.gitignore` è stato aggiunto `**/halmos_forge/out/`.

Per eseguire:
```bash
cd contracts/bank/forge/halmos_forge
forge test          # -vvvv per vedere i trace
```

## Come sono state scritte le PoC

1. Il controesempio si legge dal log di Halmos: `contracts/bank/halmos/build/halmos/logs/<vN>_<prop>.log`. Contiene `p_value`, `p_amount`, `halmos_owner_address`, `halmos_A_address`, `sender_is_contract*`, `receive_*` e il trace delle CALL.
2. La sequenza di transazioni si riproduce con gli stessi valori:
   - **mittenti:** EOA `0x8000…0000`, oppure contratti utente che corrispondono a `userContract0`/`userContract1`;
   - **reazioni del `receive`:** stesse scelte di `BankUser`. `choice 0` non fa nulla, `1` fa revert, `2` chiama Bank (direttamente o tramite il peer), `3` invia ETH. Il flag `reacted` limita la reazione a una per transazione e l'esito delle chiamate viene ignorato;
   - **owner e constructor:** stessi dell'esecuzione Halmos, usando `vm.prank` per il deploy.
3. Alla fine si verifica la condizione della proprietà. I crediti si leggono con `vm.load` su `keccak256(abi.encode(addr, slot))`: lo slot è 0, oppure 1 nelle versioni che ereditano `ReentrancyGuard`.
4. **Semantica:** un test dà **PASS solo se la violazione viene riprodotta**. Altrimenti dà FAIL con un messaggio del tipo `"... holds: counterexample not reproduced"`, oppure `"... reverted ...: counterexample not reproduced"`.

Stile usato: `pragma solidity >=0.8.2;`, `import {Test} from "forge-std/Test.sol";`, `import {Bank} from "versions/Bank_vN.sol";`, un commento iniziale con il controesempio, `contract PoC_...` con `setUp()` e `test_poc_...()`, commenti in inglese.

## Risultato attuale: 19 PoC (15 PASS, 4 FAIL)

### PASS: controesempio riprodotto (truth = 0, Halmos N! corretto)

| Versione | Proprietà | Autore | Bug sfruttato |
|---|---|---|---|
| v1 | assets-dec-onlyif-deposit | utente | il `receive` rientrante deposita più di quanto ha ricevuto durante `withdraw` |
| v2 | withdraw-revert | utente | `credits -= amount - 1`: `withdraw(1)` con credito 0 non fa revert |
| v4 | deposit-assets-credit | utente | `credits += msg.value - 1` |
| v5 | deposit-assets-credit | Claude | `credits += msg.value + 1` |
| v6 | withdraw-sender-rcv-EOA | utente | `withdraw` invia `amount + 1` |
| v7 | deposit-assets-credit-others | Claude | `deposit` fa anche `credits[owner] += 1` |
| v8 | credit-inc-onlyif-deposit | Claude | solo `withdraw` è `nonReentrant`: durante la call di u1, u0 deposita |
| v9 | assets-dec-onlyif-deposit | Claude | nella low-level call A invia ad altri più ETH di quanti ne ha ricevuti |
| v10 | credit-dec-onlyif-withdraw | Claude | il `receive` di u1 fa eseguire `withdraw` al peer u0 (3 tx) |
| v11 | withdraw-sender-credit | Claude | `withdraw` rientrante tramite low-level call: il credito cala di amount + 1 |
| v12 | withdraw-sender-rcv | Claude | manca `require(success)`: il `receive` fa revert ma `withdraw` no |
| v13 | deposit-contract-balance | Claude | `deposit` gira 1 wei all'owner: il saldo di Bank cresce di `value - 1` |
| v14 | assets-inc-onlyif-withdraw | Claude | il `receive` del sender invia ETH ad A durante un `withdraw` non suo |
| v16 | withdraw-revert | Claude | decremento unchecked e nessun `require(success)`: `withdraw(2^255)` con credito 0 non fa revert |
| v17 | credit-dec-onlyif-withdraw | Claude | `withdraw` scala i crediti da `tx.origin` invece che da `msg.sender` |

### FAIL: controesempio non eseguibile (truth = 1, Halmos N!: falsi negativi di Halmos)

| Versione | Proprietà | Controesempio di Halmos |
|---|---|---|
| v3 | withdraw-sender-credit | `withdraw(2^127)` con `withdraw(1)` rientrante dentro `transfer` |
| v15 | withdraw-sender-rcv | stessa sequenza di v3 |
| v15 | credit-inc-onlyif-deposit | dentro `transfer`, u1 invia ETH a u0 e u0 fa `deposit` |
| v13 | deposit-assets-credit-others | dentro `transfer(1)` all'owner, l'owner fa `deposit` |

**Perché falliscono.** In tutti e quattro i casi la reazione del controesempio avviene dentro un `transfer`, che passa al `receive` solo **2300 gas**. Sulla EVM reale succede questo:
1. il `receive` arriva alla prima `SSTORE` e va in `ReentrancySentryOOG` (sentry di EIP-2200);
2. il `transfer` fa revert, quindi fa revert anche `withdraw`/`deposit`, e la transazione non avviene.

Il comportamento si vede nei trace `-vvvv`. È stato controllato anche con un `receive` **senza `SSTORE`**, cioè senza il flag `reacted`: la chiamata rientrante fallisce lo stesso per OOG. Quindi il revert non dipende da come è scritta la PoC.

**Interpretazione.** Nei log di Halmos l'intera reazione viene eseguita dentro la CALL del `transfer`. Questo è coerente con il fatto che Halmos non applichi il limite di gas di 2300 (stipend), ma il meccanismo interno di Halmos non è stato verificato. I controesempi sono quindi spuri e la ground truth (1) è corretta. Il FAIL è l'esito atteso: conferma che si tratta di falsi negativi di Halmos.

## Note e limiti

- **v13 deposit-contract-balance.** Nel controesempio l'owner è `userContract0`, cioè un `BankUser`. Dentro `transfer(1)` un vero `BankUser` andrebbe in OOG anche con `choice 0`, perché scrive `reacted`. Nella PoC l'owner ha un `receive()` vuoto. La violazione è reale, ma questo controesempio preciso, con quell'owner, nell'handler non sarebbe eseguibile.
- **Le 4 PoC dell'utente** (v1, v2, v4, v6) sono state ripristinate dal commit c3905a2 ed eseguite (tutte PASS). Non sono state riconfrontate riga per riga con i log.
- **Rimosse:**
  - `withdraw-contract-balance_v9`: Halmos dà UNK e la PoC era costruita dalla ground truth (con `selfdestruct`), non da un controesempio di Halmos;
  - `deposit-revert_v4` (Halmos P, truth 0): **da riprendere**. Dall'analisi risulta che la violazione richiede `credits + value = 2^256`. Questo non è raggiungibile, perché il saldo di Bank è ≥ credits + 1 e il saldo andrebbe in overflow (`OverflowPayment`). Halmos P e il FAIL della PoC concordano, e la ground truth 0 sembra incoerente. In v16 (decremento unchecked) la violazione è raggiungibile e Halmos dà N!.
- **`forge/test/` (14 test del benchmark, generati da GPT-5):** passano tutti se compilati in un progetto con `src/`. Confermano la violazione, ma non il controesempio specifico di Halmos, e coprono solo casi con truth = 0. Non sono stati modificati.
- **Vincoli rispettati:** Halmos e il benchmark non sono stati eseguiti; nulla è stato modificato in `contracts/bank/halmos/`, nelle versioni o nei test Halmos.

## Possibili passi successivi

- Riprendere `deposit-revert_v4` (incoerenza con la ground truth).
- Aggiungere una PoC per `deposit-revert_v16`.
- Aggiungere `**/halmos_forge/cache/` a `.gitignore`.
