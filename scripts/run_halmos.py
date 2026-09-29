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

    # Locate ground-truth file (parent dir first, fallback to cwd)
    gt_path = Path("../ground-truth.csv")
    if not gt_path.exists():
        gt_path = Path("./ground-truth.csv")

    # Read ground-truth: set of valid (property, version) pairs
    gt_keys = set()
    if gt_path.exists():
        with open(gt_path, 'r', newline='') as f:
            reader = csv.reader(f)
            next(reader, None)  # skip header
            for row in reader:
                if row and len(row) >= 2:
                    gt_keys.add((row[0], row[1]))

    tasks = []

    if args.property and args.version:
        # Explicit pair: run only if present in ground-truth
        if (args.property, args.version) in gt_keys:
            tasks.append((args.property, args.version))
        else:
            print(f"Warning: ({args.property}, {args.version}) not in ground-truth, skipping.",
                  file=sys.stderr)

    elif args.property:
        # Only property: run only versions listed in ground-truth for it
        for (p, v) in sorted(gt_keys):
            if p == args.property:
                tasks.append((p, v))
        if not tasks:
            print(f"Warning: no ground-truth entries for property '{args.property}'.",
                  file=sys.stderr)

    else:
        # No filter: run all ground-truth pairs (optionally restricted by version)
        for (p, v) in sorted(gt_keys):
            if args.version and v != args.version:
                continue
            tasks.append((p, v))

    # Execute all tasks
    current_results = {}
    for p, v in tasks:
        res = halmos_tool.run_halmos_for_task(p, v, halmos_dir, output_dir, timeout_seconds)
        current_results[(p, v)] = res

    # Write out.csv: current run only (ERR entries excluded)
    out_csv_path = output_dir.joinpath('out.csv')
    out_csv = [utils.OUT_HEADER]
    for (p, v), res in current_results.items():
        if str(res).upper() not in ["ERR"]:
            out_csv.append([p, v, res])

    with open(out_csv_path, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(out_csv)

    history_path = (output_dir / ".." / ".." / ".." / "halmos.csv").resolve()

    all_current = dict(current_results)
    seen = set()
    existing_rows = []

    if history_path.exists():
        try:
            with open(history_path, 'r', newline='') as f:
                reader = csv.reader(f)
                next(reader, None)  # skip header
                for row in reader:
                    if row and len(row) >= 2:
                        key = (row[0], row[1])

                        # Drop rows not present in ground-truth
                        if key not in gt_keys:
                            continue

                        if key in all_current:
                            res = all_current[key]
                            if str(res).upper() not in ["ERR"]:
                                existing_rows.append([row[0], row[1], res])
                            # On ERR: drop the old row
                            seen.add(key)
                        else:
                            # Untouched row: keep as-is
                            existing_rows.append(row)
        except Exception as e:
            print(f"Warning: could not read history {history_path}: {e}", file=sys.stderr)

    # Add new rows from current run (only if in ground-truth)
    for (p, v), res in all_current.items():
        if (p, v) not in seen and str(res).upper() not in ["ERR"]:
            if (p, v) in gt_keys:
                existing_rows.append([p, v, res])

    # Sort alphabetically by (property, version)
    existing_rows.sort(key=lambda r: (r[0], r[1]))

    # Write back the merged history
    with open(history_path, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(utils.OUT_HEADER)
        writer.writerows(existing_rows)

    # Report each result
    for (p, v), res in current_results.items():
        print(f"Halmos result appended for {p} ({v}): {res}")


if __name__ == '__main__':
    main()