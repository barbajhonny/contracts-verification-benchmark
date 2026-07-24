"""
Script to launch Halmos within the benchmark framework and format the results for the Confusion Matrix.
"""
from pathlib import Path
import argparse
import subprocess
import csv
import sys
import re
import utils

DEFAULT_TIMEOUT = '10m'

def parse_timeout_to_seconds(timeout_str):
    try:
        if timeout_str.endswith('m'):
            return int(timeout_str[:-1]) * 60
        elif timeout_str.endswith('s'):
            return int(timeout_str[:-1])
        return int(timeout_str)
    except ValueError:
        return 600

def run_halmos_for_task(p, v, halmos_dir, output_dir, timeout_seconds):
    """
    Executes Halmos for a specific property and version, then parses the text output.
    Saves dedicated execution log files inside the build artifacts directory.
    """
    # 1. Puliamo il nome della proprietà (trattini -> underscore)
    clean_p = p.replace('-', '_')
    
    # 2. Rimuoviamo l'ancora rigida (^ e $). 
    # Passando clean_p ad Halmos, matcherà qualsiasi funzione che contiene questo nome
    target_test = clean_p
    
    print(f"Running Halmos verification for property: '{p}', version: '{v}' (matching '{target_test}')...")
    
    try:
        # Eseguiamo Halmos con il filtro flessibile
        halmos_cmd = [
            "halmos",
            "--match-test", target_test,
            "--solver-timeout-assertion", "120000"
        ]
            
        halmos_res = subprocess.run(
            halmos_cmd,
            cwd=halmos_dir, 
            capture_output=True, 
            text=True,
            timeout=timeout_seconds
        )
        output = halmos_res.stdout + halmos_res.stderr
        
        logs_dir = Path(output_dir).joinpath("logs")
        logs_dir.mkdir(parents=True, exist_ok=True)
        log_filename = f"{v}_{p}.log"
        utils.write_log(logs_dir.joinpath(log_filename), output)
        
        # Rimozione dei codici colore ANSI dai log
        ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
        clean_output = ansi_escape.sub('', output)
        
        # --- PARSING REGEX DELL'ESITO ---
        # Cerchiamo [PASS] o [FAIL] seguiti da una funzione che contiene clean_p
        pass_pattern = rf"\[PASS\]\s+.*{re.escape(clean_p)}"
        fail_pattern = rf"\[FAIL\]\s+.*{re.escape(clean_p)}"
        
        if re.search(pass_pattern, clean_output, re.IGNORECASE):
            return utils.STRONG_POSITIVE  # Mappa a 'P!'
        elif re.search(fail_pattern, clean_output, re.IGNORECASE):
            return utils.STRONG_NEGATIVE  # Mappa a 'N!'
        else:
            # Fallback generico
            if clean_p.lower() in clean_output.lower():
                if "pass" in clean_output.lower() and "fail" not in clean_output.lower():
                    return utils.STRONG_POSITIVE
                elif "fail" in clean_output.lower():
                    return utils.STRONG_NEGATIVE
            return utils.UNKNOWN
            
    except subprocess.TimeoutExpired as e:
        print(f"Timeout expired for Halmos on {p} ({v}) after {e.timeout} seconds.")
        logs_dir = Path(output_dir).joinpath("logs")
        logs_dir.mkdir(parents=True, exist_ok=True)
        log_filename = f"{v}_{p}.log"
        
        partial_output = ""
        if e.stdout:
            partial_output += e.stdout if isinstance(e.stdout, str) else e.stdout.decode()
        if e.stderr:
            partial_output += e.stderr if isinstance(e.stderr, str) else e.stderr.decode()
            
        utils.write_log(logs_dir.joinpath(log_filename), partial_output + "\n[SCRIPT TIMEOUT EXPIRED]")
        return utils.ERROR 
        
    except Exception as e:
        print(f"Error during Halmos execution for {p}: {e}")
        return utils.ERROR
    
def main(args_list=None):
    parser = argparse.ArgumentParser()
    parser.add_argument('--halmos-dir', '-hd', help='Halmos working directory.', required=False)
    parser.add_argument('--contracts', '-c', help='Contracts file or directory.', required=True)
    parser.add_argument('--output', '-o', help='Output directory.', required=True)
    parser.add_argument('--timeout', '-t', help='Timeout time.', required=False)
    parser.add_argument('--version', '-v', help='Run on this version only.', required=False)
    parser.add_argument('--property', '-p', help='Run on this property only.', required=False)
    
    if args_list is not None:
        args = parser.parse_args(args_list)
    else:
        args = parser.parse_args()

    # ---- HALMOS_DIR ----
    if args.halmos_dir:
        halmos_dir = Path(args.halmos_dir)
    else:
        halmos_dir = Path("./halmos")

    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    timeout = args.timeout if args.timeout else DEFAULT_TIMEOUT
    timeout_seconds = parse_timeout_to_seconds(timeout)
    
    tasks = []
    
    # 1. Ricerca del ground-truth.csv
    gt_path = Path("../ground-truth.csv")
    if not gt_path.exists():
        gt_path = Path("./ground-truth.csv")

    # 2. Popolamento dei task in base alle flag ricevute
    if args.property and args.version:
        # Caso specifico: una singola proprietà su una singola versione
        tasks.append((args.property, args.version))

    elif args.property and not args.version:
        # Caso in cui è specificata solo la proprietà: cerchiamo tutte le versioni per quella proprietà nel CSV
        if gt_path.exists():
            with open(gt_path, 'r') as f:
                reader = csv.reader(f)
                next(reader)
                for row in reader:
                    if row and len(row) >= 2 and row[0] == args.property:
                        tasks.append((row[0], row[1]))
        if not tasks:
            # Fallback se non trovata nel CSV
            tasks.append((args.property, 'v1'))

    else:
        # Caso generale: caricamento dal CSV con eventuale filtro su --version
        if gt_path.exists():
            with open(gt_path, 'r') as f:
                reader = csv.reader(f)
                next(reader)
                for row in reader:
                    if row and len(row) >= 2:
                        prop_name, ver_name = row[0], row[1]
                        # Se l'utente ha passato --version, filtriamo solo quella versione!
                        if args.version and ver_name != args.version:
                            continue
                        tasks.append((prop_name, ver_name))
        else:
            tasks.append(("unknown-property", "v1"))
            
    current_results = {}
    for p, v in tasks:
        res = run_halmos_for_task(p, v, halmos_dir, output_dir, timeout_seconds)
        current_results[(p, v)] = res

    # Salvataggio e aggiornamento di out.csv
    out_csv_path = output_dir.joinpath('out.csv')
    existing_rows = []
    if out_csv_path.exists():
        try:
            with open(out_csv_path, 'r') as f:
                reader = csv.reader(f)
                next(reader)
                for row in reader:
                    if row:
                        if (row[0], row[1]) not in current_results:
                            existing_rows.append(row)
        except Exception:
            pass

    out_csv = [utils.OUT_HEADER] + existing_rows
    for (p, v), res in current_results.items():
        out_csv.append([p, v, res])

    with open(out_csv_path, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(out_csv)
        
    for (p, v), res in current_results.items():
        print(f"Halmos result appended for {p} ({v}): {res}")

if __name__ == '__main__':
    main()