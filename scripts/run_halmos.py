"""
CLI entry point to launch Halmos benchmark and record results into out.csv.
"""
from pathlib import Path
import argparse
import csv
import sys
import utils

PROJECT_ROOT = Path(__file__).resolve().parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from scripts.tools import halmos as halmos_tool

DEFAULT_TIMEOUT = '10m'


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

    if args.halmos_dir:
        halmos_dir = Path(args.halmos_dir)
    else:
        halmos_dir = Path("./halmos")

    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    timeout = args.timeout if args.timeout else DEFAULT_TIMEOUT
    timeout_seconds = halmos_tool.parse_timeout_to_seconds(timeout)

    tasks = []

    gt_path = Path("../ground-truth.csv")
    if not gt_path.exists():
        gt_path = Path("./ground-truth.csv")

    def discover_versions(h_dir):
        vers = set()
        h_path = Path(h_dir)
        if h_path.exists():
            for f in h_path.rglob("*.sol"):
                parts = f.stem.split('_')
                if parts and parts[0].startswith('v'):
                    vers.add(parts[0])
        return sorted(list(vers), key=lambda x: int(x[1:]) if x[1:].isdigit() else 0)

    # Build tasks list based on flags
    if args.property and args.version:
        tasks.append((args.property, args.version))

    elif args.property and not args.version:
        available_versions = discover_versions(halmos_dir)
        if available_versions:
            for v in available_versions:
                tasks.append((args.property, v))
        else:
            if gt_path.exists():
                with open(gt_path, 'r') as f:
                    reader = csv.reader(f)
                    next(reader)
                    for row in reader:
                        if row and len(row) >= 2 and row[0] == args.property:
                            tasks.append((row[0], row[1]))
            if not tasks:
                tasks.append((args.property, 'v1'))

    else:
        if gt_path.exists():
            with open(gt_path, 'r') as f:
                reader = csv.reader(f)
                next(reader)
                for row in reader:
                    if row and len(row) >= 2:
                        prop_name, ver_name = row[0], row[1]
                        if args.version and ver_name != args.version:
                            continue
                        tasks.append((prop_name, ver_name))
        else:
            tasks.append(("unknown-property", "v1"))

    current_results = {}
    for p, v in tasks:
        res = halmos_tool.run_halmos_for_task(p, v, halmos_dir, output_dir, timeout_seconds)
        current_results[(p, v)] = res

    out_csv_path = output_dir.joinpath('out.csv')
    out_csv = [utils.OUT_HEADER]
    for (p, v), res in current_results.items():
        if str(res).upper() not in ["ERR"]:
            out_csv.append([p, v, res])

    with open(out_csv_path, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(out_csv)


        # ------------------------------------------------------------------
    # 2. halmos.csv = storico cumulativo (merge + ordinamento alfabetico)
    # ------------------------------------------------------------------
    history_path = (output_dir / ".." / ".." / ".." / "halmos.csv").resolve()

    # (prop, ver) -> res per la run corrente, INCLUSI gli ERR
    all_current = dict(current_results)
    seen = set()
    existing_rows = []

    if history_path.exists():
        try:
            with open(history_path, 'r', newline='') as f:
                reader = csv.reader(f)
                next(reader, None)  # salta header
                for row in reader:
                    if row and len(row) >= 2:
                        key = (row[0], row[1])
                        if key in all_current:
                            res = all_current[key]
                            if str(res).upper() not in ["ERR"]:
                                # aggiorna il risultato mantenendo property/version
                                existing_rows.append([row[0], row[1], res])
                            # se ERR: scarta (non riaggiunge)
                            seen.add(key)
                        else:
                            # riga non toccata: preserva
                            existing_rows.append(row)
        except Exception as e:
            print(f"Warning: could not read history {history_path}: {e}", file=sys.stderr)

    # righe nuove (non presenti nello storico)
    for (p, v), res in all_current.items():
        if (p, v) not in seen and str(res).upper() not in ["ERR"]:
            existing_rows.append([p, v, res])

    # ordina alfabeticamente per (property, version)
    existing_rows.sort(key=lambda r: (r[0], r[1]))

    # scrivi
    with open(history_path, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(utils.OUT_HEADER)
        writer.writerows(existing_rows)

    for (p, v), res in current_results.items():
        print(f"Halmos result appended for {p} ({v}): {res}")


if __name__ == '__main__':
    main()