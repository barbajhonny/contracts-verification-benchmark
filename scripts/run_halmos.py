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

def extract_contract_name(file_path):
    """Extract contract name from a Solidity test file."""
    try:
        with open(file_path, 'r') as f:
            content = f.read()
        match = re.search(r'contract\s+(\w+)', content)
        if match:
            return match.group(1)
    except Exception:
        pass
    return None

def run_halmos_for_task(p, v, halmos_dir, output_dir, timeout_seconds, halmos_cmd_base=None):
    """
    Executes Halmos for a specific property and version, then parses the text output.
    """
    target_test = f"check_{p.replace('-', '_')}"
    print(f"Running Halmos verification for property: '{p}', version: '{v}'...")
    
    halmos_cmd = (halmos_cmd_base or ["halmos", "--solver-timeout-assertion", "120000"]).copy()
    
    try:
        halmos_res = subprocess.run(
            halmos_cmd,
            cwd=halmos_dir, 
            capture_output=True, 
            text=True,
            timeout=timeout_seconds
        )
        output = halmos_res.stdout + halmos_res.stderr
        
        # Save log
        logs_dir = Path(output_dir).joinpath("logs")
        logs_dir.mkdir(parents=True, exist_ok=True)
        log_filename = f"{v}_{p}.log"
        utils.write_log(logs_dir.joinpath(log_filename), output)
        
        # Strip ANSI
        ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
        clean_output = ansi_escape.sub('', output)
        
        # Parse result
        pass_pattern = rf"\[PASS\]\s+{re.escape(target_test)}\s*\(.*?\)"
        fail_pattern = rf"\[FAIL\]\s+{re.escape(target_test)}\s*\(.*?\)"
        
        if re.search(pass_pattern, clean_output, re.IGNORECASE):
            return utils.STRONG_POSITIVE  # P!
        elif re.search(fail_pattern, clean_output, re.IGNORECASE):
            return utils.STRONG_NEGATIVE  # N!
        else:
            if target_test.lower() in clean_output.lower():
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

    halmos_dir = Path(args.halmos_dir) if args.halmos_dir else Path("./halmos")
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    timeout = args.timeout if args.timeout else DEFAULT_TIMEOUT
    timeout_seconds = parse_timeout_to_seconds(timeout)
    
    contracts_path = Path(args.contracts)
    is_single_test = contracts_path.is_file() and contracts_path.suffix == '.t.sol'
    
    # Build base Halmos command
    halmos_cmd_base = ["halmos", "--solver-timeout-assertion", "120000"]
    
    # Determine tasks
    tasks = []
    
    if is_single_test:
        # SINGLE TEST FILE MODE (contracts/bank/ make one)
        filename = contracts_path.name.replace('.t.sol', '')
        parts = filename.split('_', 1)
        if len(parts) == 2:
            version, prop_name = parts
            tasks.append((prop_name, version))
            print(f"Single test mode: {filename} -> property='{prop_name}', version='{version}'")
        else:
            print(f"Warning: Could not parse version/property from filename: {filename}")
            tasks.append(("unknown", "v1"))
        
        # Add --match-contract to filter Halmos
        contract_name = extract_contract_name(contracts_path)
        if contract_name:
            halmos_cmd_base.extend(["--match-contract", contract_name])
            print(f"Filtering Halmos for contract: {contract_name}")
        else:
            print(f"Warning: Could not extract contract name from {contracts_path}")
    else:
        # ORIGINAL MODE (regression/ batch, or contracts/bank/ batch)
        print(f"Batch mode: reading tasks from ground-truth.csv or args")
        if args.property and args.version:
            tasks.append((args.property, args.version))
        else:
            gt_path = Path("../ground-truth.csv")
            if not gt_path.exists():
                gt_path = Path("./ground-truth.csv")
            if gt_path.exists():
                with open(gt_path, 'r') as f:
                    reader = csv.reader(f)
                    next(reader)
                    for row in reader:
                        if row and len(row) >= 2:
                            tasks.append((row[0], row[1]))
            else:
                tasks.append(("unknown-property", "v1"))
            
    current_results = {}
    for p, v in tasks:
        res = run_halmos_for_task(p, v, halmos_dir, output_dir, timeout_seconds, halmos_cmd_base)
        current_results[(p, v)] = res

    # Write out.csv (always generated)
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