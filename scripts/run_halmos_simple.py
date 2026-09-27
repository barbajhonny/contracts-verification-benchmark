import argparse
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent

#DA FINIRE ANCORA, AGGIUSTARE LA TABELLA CSV, NON LA AGGIORNA , LA SOVVRASCRIVE, DA FIXARE!!

def main():
    parser = argparse.ArgumentParser(description='Halmos benchmark orchestrator')
    parser.add_argument('--contract', action='store', required=True, type=str)
    parser.add_argument('--version', action='store', required=False, type=str)
    parser.add_argument('--property', action='store', required=False, type=str)
    parser.add_argument('--timeout', action='store', required=False, default="600")
    args = parser.parse_args()

    contract_dir = PROJECT_ROOT / "contracts" / args.contract / "halmos"

    print(f"[DEBUG] SCRIPT_DIR   = {SCRIPT_DIR}")
    print(f"[DEBUG] PROJECT_ROOT = {PROJECT_ROOT}")
    print(f"[DEBUG] contract_dir = {contract_dir}")
    print(f"[DEBUG] exists?      = {contract_dir.exists()}")

    if not contract_dir.exists():
        print(f"Error: {contract_dir} does not exist", file=sys.stderr)
        sys.exit(1)

    # verifica che il Makefile esista
    makefile = contract_dir / "Makefile"
    print(f"[DEBUG] Makefile     = {makefile} (exists={makefile.exists()})")

    make_cmd = ["make", "run"]
    if args.version:
        make_cmd.append(f"ver={args.version}")
    if args.property:
        make_cmd.append(f"prop={args.property}")
    if args.timeout:
        make_cmd.append(f"to={args.timeout}")

    print(f"[DEBUG] cmd          = {' '.join(make_cmd)}")
    print(f"[DEBUG] cwd          = {contract_dir}")

    try:
        subprocess.run(make_cmd, cwd=contract_dir, check=True)
    except subprocess.CalledProcessError as e:
        print(f"\nmake failed with exit code {e.returncode}", file=sys.stderr)
        sys.exit(e.returncode)


if __name__ == '__main__':
    main()