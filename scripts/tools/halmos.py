"""
Core execution and helper functions for Halmos verification tool integration.
"""
from pathlib import Path
import subprocess
import re
import utils


def parse_timeout_to_seconds(timeout_str):
    """Convert timeout string (e.g., '10m', '600s') to seconds integer."""
    try:
        if timeout_str.endswith('m'):
            return int(timeout_str[:-1]) * 60
        elif timeout_str.endswith('s'):
            return int(timeout_str[:-1])
        return int(timeout_str)
    except ValueError:
        return 600


def check_test_exists_in_contracts(halmos_dir, clean_p):
    """Check if any .sol file in halmos_dir contains a function matching clean_p."""
    halmos_path = Path(halmos_dir)
    if not halmos_path.exists():
        return True

    for sol_file in halmos_path.rglob("*.sol"):
        try:
            content = sol_file.read_text(encoding="utf-8")
            pattern = rf"function\s+[a-zA-Z0-9_]*{re.escape(clean_p)}[a-zA-Z0-9_]*\s*\("
            if re.search(pattern, content, re.IGNORECASE):
                return True
        except Exception:
            continue

    return False


def extract_test_contract_name(file_path, clean_p):
    """Extract the specific contract name enclosing the test function."""
    try:
        content = Path(file_path).read_text(encoding="utf-8")

        test_search = clean_p
        if test_search.startswith("check_"):
            test_search = test_search[6:]
        elif test_search.startswith("invariant_"):
            test_search = test_search[10:]

        contracts = re.findall(r'\bcontract\s+([a-zA-Z0-9_]+)', content)
        if not contracts:
            return None

        if len(contracts) == 1:
            return contracts[0]

        parts = content.split("contract ")
        for part in parts[1:]:
            lines = part.splitlines()
            c_name = lines[0].split()[0].split('{')[0].strip()
            if test_search.lower() in part.lower():
                return c_name

        return contracts[-1]

    except Exception:
        return None


def run_halmos_for_task(p, v, halmos_dir, output_dir, timeout_seconds):
    """Execute Halmos verification for a given property and version task."""
    clean_p = p.replace('-', '_')
    halmos_path = Path(halmos_dir)
    target_file_path = None

    # Locate target .t.sol file
    if v:
        matches = list(halmos_path.rglob(f"{v}_{p}.t.sol")) + list(halmos_path.rglob(f"{v}_{clean_p}.t.sol"))
        if matches:
            target_file_path = matches[0]

    if not target_file_path:
        matches = list(halmos_path.rglob(f"{p}.t.sol")) + list(halmos_path.rglob(f"{clean_p}.t.sol"))
        if matches:
            target_file_path = matches[0]

    # Verify if test function exists
    if not check_test_exists_in_contracts(halmos_dir, clean_p):
        return utils.ERROR

    print(f"Running Halmos verification for property: '{p}', version: ({v}) -> File: {target_file_path}")

    try:
        test_match = clean_p
        if test_match.startswith("check_"):
            test_match = test_match[6:]
        elif test_match.startswith("invariant_"):
            test_match = test_match[10:]

        solver_timeout_ms = str(timeout_seconds * 1000)

        halmos_cmd = [
            "halmos",
            "--match-test", test_match,
            "--solver-timeout-assertion", solver_timeout_ms
        ]

        if target_file_path and target_file_path.exists():
            contract_name = extract_test_contract_name(target_file_path, clean_p)
            if contract_name:
                halmos_cmd.extend(["--contract", contract_name])

        # Execute Halmos process
        halmos_res = subprocess.run(
            halmos_cmd,
            cwd=halmos_dir,
            capture_output=True,
            text=True,
            timeout=timeout_seconds
        )

        output = halmos_res.stdout + "\n" + halmos_res.stderr

        # Save logs
        logs_dir = Path(output_dir).joinpath("logs")
        logs_dir.mkdir(parents=True, exist_ok=True)
        log_filename = f"{v}_{p}.log" if v else f"{p}.log"
        utils.write_log(logs_dir.joinpath(log_filename), output)

        # Strip ANSI colors from output
        ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
        clean_output = ansi_escape.sub('', output)

        # Parse verification results
        fail_pattern = rf"\[FAIL\]\s+.*{re.escape(test_match)}"
        pass_pattern = rf"\[PASS\]\s+.*{re.escape(test_match)}"

        if re.search(fail_pattern, clean_output, re.IGNORECASE) or (
            re.search(rf"{re.escape(test_match)}", clean_output, re.IGNORECASE) and "Counterexample:" in clean_output
        ):
            return utils.STRONG_NEGATIVE

        elif re.search(pass_pattern, clean_output, re.IGNORECASE):
            return utils.STRONG_POSITIVE

        else:
            lines = [line for line in clean_output.split('\n') if test_match.lower() in line.lower()]
            for line in lines:
                if "[fail]" in line.lower():
                    return utils.STRONG_NEGATIVE
                if "[pass]" in line.lower():
                    return utils.STRONG_POSITIVE

            return utils.UNKNOWN

    except subprocess.TimeoutExpired:
        return utils.UNKNOWN
    except Exception as e:
        print(f"Error during Halmos execution for {p}: {e}")
        return utils.ERROR