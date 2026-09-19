import argparse
import sys
import os

def main():
    parser = argparse.ArgumentParser(description='Halmos benchmark orchestrator')
    parser.add_argument('--contract', action='store', required=True, type=str,
                        help="contract to run the experiments")
    parser.add_argument('--version', action='store', required=False, type=str,
                        help="version of the contract over which to run the experiments")
    parser.add_argument('--property', action='store', required=False, type=str,
                        help="property of the contract over which to run the experiments")
    parser.add_argument('--timeout', action='store', required=False, default="600",
                        help="timeout for each verification task")

    args = parser.parse_args()

    contract_dir = f"../contracts/{args.contract}/halmos"
    contracts_build_dir = f"{contract_dir}/build/contracts"

    import run_halmos

    args_halmos = [
        "--contracts", contracts_build_dir,
        "--output", f"{contract_dir}/build/halmos",
        "--halmos-dir", contracts_build_dir
    ]

    # SE specifici la versione, la passiamo. ALTRIMENTI non passiamo nulla 
    # e run_halmos capirà che deve eseguirli tutti!
    if args.version:
        args_halmos += ["--version", args.version]

    if args.property:
        args_halmos += ["--property", args.property]
        
    if args.timeout:
        args_halmos += ["--timeout", args.timeout]

    run_halmos.main(args_halmos)

if __name__ == '__main__':
    main()