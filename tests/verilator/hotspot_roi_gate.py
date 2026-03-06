#!/usr/bin/env python3
"""Fail when selected hotspot files show no uncovered-marker improvement."""

from __future__ import annotations

import argparse
import subprocess
import sys


def run_delta(before_dat: str, after_dat: str, files: list[str]) -> subprocess.CompletedProcess:
    cmd = ["python3", "tests/verilator/hotspot_delta.py", before_dat, after_dat]
    for f in files:
        cmd.extend(["--file", f])
    return subprocess.run(cmd, text=True, capture_output=True, check=False)


def parse_deltas(text: str) -> dict[str, int]:
    deltas: dict[str, int] = {}
    for line in text.splitlines():
        parts = line.strip().split()
        if len(parts) < 4:
            continue
        name = parts[0]
        if "/" not in parts[1] or "/" not in parts[2]:
            continue
        try:
            deltas[name] = int(parts[3])
        except ValueError:
            continue
    return deltas


def main() -> int:
    parser = argparse.ArgumentParser(description="ROI gate for selected hotspot files")
    parser.add_argument("before_dat", help="Older merged coverage .dat")
    parser.add_argument("after_dat", help="Newer merged coverage .dat")
    parser.add_argument(
        "--file",
        action="append",
        dest="files",
        default=None,
        help="File basename(s) to gate; may be passed multiple times",
    )
    args = parser.parse_args()

    files = args.files or ["ym7101.v", "68k.v", "z80.v"]
    files = list(dict.fromkeys(files))

    res = run_delta(args.before_dat, args.after_dat, files)
    if res.returncode != 0:
        print(res.stdout, end="")
        print(res.stderr, end="", file=sys.stderr)
        return res.returncode

    print(res.stdout, end="")
    deltas = parse_deltas(res.stdout)
    if not deltas:
        print("ROI gate: unable to parse hotspot deltas", file=sys.stderr)
        return 3

    improved = [name for name, delta in deltas.items() if delta < 0]
    if improved:
        print(f"ROI gate: PASS (improved: {', '.join(improved)})")
        return 0

    print("ROI gate: FAIL (no selected hotspot file improved)")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
