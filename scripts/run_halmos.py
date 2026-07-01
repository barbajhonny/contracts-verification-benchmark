"""
Script to launch Halmos within the benchmark and format the results for the Confusion Matrix.
"""
from pathlib import Path
import argparse
import subprocess
import csv

# Standard header used by the confusion matrix benchmark
OUT_HEADER = ['property', 'version', 'result']

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--contracts', '-c', help='Path to the contract file.', required=True)
    parser.add_argument('--output', '-o', help='Output directory (build/halmos).', required=True)
    args = parser.parse_args()

    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    halmos_dir = Path("./halmos")
    
    # 1. DYNAMIC VERSION EXTRACTION
    contract_name = Path(args.contracts).stem
    if '_v' in contract_name:
        v = contract_name.split('_')[-1]
    else:
        v = 'v1'

    # 2. DYNAMIC PROPERTY EXTRACTION FROM GROUND TRUTH
    # Reading the local ground-truth.csv to safely find the property name
    p = "unknown-property"
    gt_path = Path("./ground-truth.csv")
    if gt_path.exists():
        try:
            with open(gt_path, 'r') as f:
                reader = csv.reader(f)
                header = next(reader)
                # If the header has at least 3 columns (property, version, ground_truth)
                if len(header) >= 1:
                    # Read the first data row to get the property name
                    first_row = next(reader)
                    if first_row:
                        p = first_row[0]
        except Exception:
            p = "unknown-property"
            
    print(f"Running Halmos verification for property: '{p}', version: '{v}'...")
    
    # We run forge clean, forge build and halmos capturing the output    
    try:
        subprocess.run(["forge", "clean"], cwd=halmos_dir, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(["forge", "build"], cwd=halmos_dir, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        halmos_res = subprocess.run(["halmos"], cwd=halmos_dir, capture_output=True, text=True)
        output = halmos_res.stdout + halmos_res.stderr
        
        # Mapping results using the benchmark standard (P = Violated, N = Safe)
        if "disproved" in output or "FAIL" in output:
            result = "P!"      # Positive (Property disproved/failed -> Bug found)
        elif "proved" in output or "PASS" in output:
            result = "N!"      # Negative (Property proved/passed -> Safe code)
        else:
            result = "unknown"
            
    except Exception as e:
        print(f"Error during execution...: {e}")
        result = "unknown"

    # Formatting dynamic output row
    out_csv = [OUT_HEADER, [p, v, result]]
    out_csv_path = output_dir.joinpath('out.csv')

    # Writing the out.csv file
    with open(out_csv_path, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(out_csv)
        
    print(f"Halmos result in {out_csv_path} state: {result}")

if __name__ == '__main__':
    main()