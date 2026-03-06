#!/usr/bin/env python3
"""Compare uncovered marker deltas for selected files between two coverage datasets."""

from __future__ import annotations

import argparse
import shutil
import subprocess
from pathlib import Path


def run(cmd: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, text=True, capture_output=True, check=False)


def annotate(cov_dat: Path, outdir: Path) -> None:
    if outdir.exists():
        shutil.rmtree(outdir)
    res = run(["verilator_coverage", "--annotate", str(outdir), str(cov_dat)])
    if res.returncode != 0:
        raise RuntimeError(res.stderr.strip() or f"annotate failed for {cov_dat}")


def file_stats(annotated_dir: Path) -> dict[str, tuple[int, int]]:
    stats: dict[str, tuple[int, int]] = {}
    for path in annotated_dir.rglob("*"):
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        lines = text.splitlines()
        zero = sum(1 for line in lines if "%00" in line)
        stats[path.name] = (zero, len(lines))
    return stats


def pct(covered: int, total: int) -> float:
    return 0.0 if total == 0 else (100.0 * covered / total)


def main() -> int:
    parser = argparse.ArgumentParser(description="Compare per-file uncovered coverage marker deltas")
    parser.add_argument("before_dat", help="Older merged coverage .dat")
    parser.add_argument("after_dat", help="Newer merged coverage .dat")
    parser.add_argument(
        "--file",
        action="append",
        dest="files",
        default=None,
        help="File basename(s) to report; may be passed multiple times",
    )
    parser.add_argument("--before-dir", default="/tmp/vcov_delta_before", help="Temporary annotate dir for before")
    parser.add_argument("--after-dir", default="/tmp/vcov_delta_after", help="Temporary annotate dir for after")
    args = parser.parse_args()

    before_dat = Path(args.before_dat)
    after_dat = Path(args.after_dat)
    if not before_dat.exists():
        print(f"Missing before coverage file: {before_dat}")
        return 2
    if not after_dat.exists():
        print(f"Missing after coverage file: {after_dat}")
        return 2

    files = args.files or ["ym7101.v", "68k.v", "z80.v"]
    files = list(dict.fromkeys(files))

    before_dir = Path(args.before_dir)
    after_dir = Path(args.after_dir)
    annotate(before_dat, before_dir)
    annotate(after_dat, after_dir)

    before = file_stats(before_dir)
    after = file_stats(after_dir)

    print("File delta (negative uncovered delta is improvement):")
    print("file before_uncovered after_uncovered delta_uncovered before_cov% after_cov%")
    for name in files:
        b_zero, b_total = before.get(name, (0, 0))
        a_zero, a_total = after.get(name, (0, 0))
        b_cov = b_total - b_zero
        a_cov = a_total - a_zero
        print(
            f"{name} {b_zero}/{b_total} {a_zero}/{a_total} {a_zero - b_zero:+d} "
            f"{pct(b_cov, b_total):.2f} {pct(a_cov, a_total):.2f}"
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
