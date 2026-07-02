# Call Verifier

## Specification
The contract has only the function `f` that performs an external call:
```
function f(address a) public {
    (bool s, bytes memory data) = a.call("");
}
```
The properties `call-failure` and `call-success` should both fail since we cannot know if the call will fail or not.

The property `ex-call-is-made` checks if an external call appened.


## Properties
- **call-failure**: the external call fails
- **call-success**: the external call succeeds
- **ex-call-is-made**: an external call has been performed

## Ground truth

- [Ground truth](ground-truth.csv)
- [Solcmc/z3](solcmc-z3.csv)
- [Solcmc/Eldarica](solcmc-eld.csv)
- [Certora](certora.csv)
- [Halmos](halmos.csv)

## Experiments
### SolCMC
#### Z3
|        | call-failure    | call-success    | ex-call-is-made |
|--------|-----------------|-----------------|-----------------|
| **v1** | TN!             | TN!             | ND              |
 

#### ELD
|        | call-failure    | call-success    | ex-call-is-made |
|--------|-----------------|-----------------|-----------------|
| **v1** | TN!             | TN!             | ND              |
 


### Certora
|        | call-failure    | call-success    | ex-call-is-made |
|--------|-----------------|-----------------|-----------------|
| **v1** | ERR             | ERR             | ERR             |
 


### Halmos
|        | call-failure    | call-success    | ex-call-is-made |
|--------|-----------------|-----------------|-----------------|
| **v1** | FP!             | FP!             | TP!             |
 

