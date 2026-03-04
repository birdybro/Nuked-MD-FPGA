#!/usr/bin/env python3
"""Summarize uncovered Verilator coverage points by file."""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
from pathlib import Path

ZERO_RE = re.compile(r"%00")
PCT_RE = re.compile(r"Total coverage \((\d+)/(\d+)\)\s+(\d+\.\d+)%")


def run(cmd: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, text=True, capture_output=True, check=False)


def main() -> int:
    parser = argparse.ArgumentParser(description="Report Verilator coverage hotspots from a merged .dat")
    parser.add_argument("coverage_dat", help="Path to merged coverage .dat")
    parser.add_argument("--top", type=int, default=20, help="Max files to print")
    parser.add_argument("--workdir", default="/tmp/vcov_hotspots", help="Temporary annotate directory")
    args = parser.parse_args()

    cov = Path(args.coverage_dat)
    if not cov.exists():
        print(f"Missing coverage file: {cov}")
        return 2

    outdir = Path(args.workdir)
    if outdir.exists():
        shutil.rmtree(outdir)

    res = run(["verilator_coverage", "--annotate", str(outdir), str(cov)])
    if res.returncode != 0:
        print(res.stderr)
        return res.returncode

    m = PCT_RE.search(res.stdout)
    if m:
        print(f"Total coverage: {m.group(1)}/{m.group(2)} ({m.group(3)}%)")
    else:
        print("Total coverage: unavailable")

    rows: list[tuple[int, int, str]] = []
    for path in outdir.rglob("*"):
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        lines = text.splitlines()
        zero_lines = sum(1 for line in lines if ZERO_RE.search(line))
        if zero_lines == 0:
            continue
        rows.append((zero_lines, len(lines), str(path)))

    rows.sort(reverse=True)
    print("\nTop uncovered files (%00 markers):")
    for zero, total, name in rows[: args.top]:
        print(f"- {zero:5d} / {total:5d} : {name}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
