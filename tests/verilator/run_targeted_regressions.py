#!/usr/bin/env python3
"""Run targeted assertion/vector regressions with Verilator."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Dict, List

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "tests" / "verilator" / "targeted_out"
BUILD_DIR = OUT / "build"
COV_DIR = OUT / "coverage"
LOG_DIR = OUT / "logs"
BASELINE_FILE = ROOT / "tests" / "verilator" / "baselines" / "targeted_signatures.json"

SIGN_RE = re.compile(r"SIGNATURE\s+([0-9a-fA-F]+)")

TESTS = [
    {
        "name": "tmss_assert",
        "top": "tb_tmss_assert",
        "tb": ROOT / "tests" / "verilator" / "regressions" / "tb_tmss_assert.sv",
        "check_signature": False,
    },
    {
        "name": "ym3438_prescaler_assert",
        "top": "tb_ym3438_prescaler_assert",
        "tb": ROOT / "tests" / "verilator" / "regressions" / "tb_ym3438_prescaler_assert.sv",
        "check_signature": False,
    },
    {
        "name": "ym3438_io_vector",
        "top": "tb_ym3438_io_vector",
        "tb": ROOT / "tests" / "verilator" / "regressions" / "tb_ym3438_io_vector.sv",
        "check_signature": True,
    },
    {
        "name": "tmss_bus_transaction",
        "top": "tb_tmss_bus_transaction",
        "tb": ROOT / "tests" / "verilator" / "regressions" / "tb_tmss_bus_transaction.sv",
        "check_signature": False,
    },
    {
        "name": "tmss_vector",
        "top": "tb_tmss_vector",
        "tb": ROOT / "tests" / "verilator" / "regressions" / "tb_tmss_vector.sv",
        "check_signature": True,
    },
    {
        "name": "ym6046_vector",
        "top": "tb_ym6046_vector",
        "tb": ROOT / "tests" / "verilator" / "regressions" / "tb_ym6046_vector.sv",
        "check_signature": True,
    },
    {
        "name": "ym7101_vector",
        "top": "tb_ym7101_vector",
        "tb": ROOT / "tests" / "verilator" / "regressions" / "tb_ym7101_vector.sv",
        "check_signature": True,
    },
    {
        "name": "ym7101_dma_vector",
        "top": "tb_ym7101_dma_vector",
        "tb": ROOT / "tests" / "verilator" / "regressions" / "tb_ym7101_dma_vector.sv",
        "check_signature": True,
    },
    {
        "name": "m68k_vector",
        "top": "tb_m68k_vector",
        "tb": ROOT / "tests" / "verilator" / "regressions" / "tb_m68k_vector.sv",
        "check_signature": True,
    },
    {
        "name": "m68k_exceptions_vector",
        "top": "tb_m68k_exceptions_vector",
        "tb": ROOT / "tests" / "verilator" / "regressions" / "tb_m68k_exceptions_vector.sv",
        "check_signature": True,
    },
    {
        "name": "ym6045_vector",
        "top": "tb_ym6045_vector",
        "tb": ROOT / "tests" / "verilator" / "regressions" / "tb_ym6045_vector.sv",
        "check_signature": True,
    },
    {
        "name": "z80_bus_vector",
        "top": "tb_z80_bus_vector",
        "tb": ROOT / "tests" / "verilator" / "regressions" / "tb_z80_bus_vector.sv",
        "check_signature": True,
    },
    {
        "name": "z80_instr_vector",
        "top": "tb_z80_instr_vector",
        "tb": ROOT / "tests" / "verilator" / "regressions" / "tb_z80_instr_vector.sv",
        "check_signature": True,
    },
    {
        "name": "md_board_cart_vector",
        "top": "tb_md_board_cart_vector",
        "tb": ROOT / "tests" / "verilator" / "regressions" / "tb_md_board_cart_vector.sv",
        "check_signature": True,
    },
]


def run(cmd: List[str], cwd: Path | None = None, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=cwd, check=check, text=True, capture_output=True)


def source_files() -> List[Path]:
    files = sorted(ROOT.glob("*.v"))
    memstubs = ROOT / "icarus" / "memstubs.v"
    if memstubs.exists():
        files.append(memstubs)
    return files


def write_main_cpp(test_name: str, top: str, cov_file: Path) -> Path:
    cpp = OUT / f"{test_name}_main.cpp"
    lines = [
        '#include "verilated.h"',
        '#include "verilated_cov.h"',
        f'#include "V{top}.h"',
        "",
        "static vluint64_t main_time = 0;",
        "double sc_time_stamp() { return static_cast<double>(main_time); }",
        "",
        "int main(int argc, char** argv) {",
        "    Verilated::commandArgs(argc, argv);",
        f"    auto* top = new V{top};",
        "    while (!Verilated::gotFinish()) {",
        "        top->eval();",
        "        ++main_time;",
        "    }",
        f'    VerilatedCov::write("{cov_file}");',
        "    delete top;",
        "    return 0;",
        "}",
    ]
    cpp.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return cpp


def build_and_run(test: dict) -> tuple[bool, str, str | None]:
    name = test["name"]
    top = test["top"]
    tb = Path(test["tb"])
    if not tb.exists():
        return False, f"missing testbench: {tb}", None

    mdir = BUILD_DIR / name
    mdir.mkdir(parents=True, exist_ok=True)
    cov_file = COV_DIR / f"{name}.dat"
    main_cpp = write_main_cpp(name, top, cov_file)

    cmd = [
        "verilator",
        "-Wno-fatal",
        "--timing",
        "--coverage",
        "--cc",
        "--exe",
        "--build",
        "--Mdir",
        str(mdir),
        "--top-module",
        top,
        str(tb),
        str(main_cpp),
        *[str(f) for f in source_files()],
    ]
    b = run(cmd, cwd=ROOT, check=False)
    if b.returncode != 0:
        return False, f"build failed\nSTDOUT:\n{b.stdout}\nSTDERR:\n{b.stderr}", None

    exe = mdir / f"V{top}"
    if not exe.exists():
        return False, f"missing executable: {exe}", None

    r = run([str(exe)], cwd=ROOT, check=False)
    if r.returncode != 0:
        return False, f"run failed\nSTDOUT:\n{r.stdout}\nSTDERR:\n{r.stderr}", None

    sig = None
    m = SIGN_RE.search(r.stdout)
    if m:
        sig = m.group(1).lower()

    return True, f"run ok\n{r.stdout}", sig


def load_baselines() -> Dict[str, str]:
    if not BASELINE_FILE.exists():
        return {}
    with BASELINE_FILE.open("r", encoding="utf-8") as fh:
        data = json.load(fh)
    return {str(k): str(v).lower() for k, v in data.items()}


def save_baselines(baselines: Dict[str, str]) -> None:
    BASELINE_FILE.parent.mkdir(parents=True, exist_ok=True)
    with BASELINE_FILE.open("w", encoding="utf-8") as fh:
        json.dump(dict(sorted(baselines.items())), fh, indent=2)
        fh.write("\n")


def merge_coverage() -> Path | None:
    cov_files = sorted(COV_DIR.glob("*.dat"))
    if not cov_files:
        return None
    merged = COV_DIR / "merged.dat"
    cmd = ["verilator_coverage", "--write", str(merged), *[str(f) for f in cov_files]]
    res = run(cmd, cwd=ROOT, check=False)
    if res.returncode != 0:
        return None
    return merged


def main() -> int:
    parser = argparse.ArgumentParser(description="Run targeted assertion/vector regressions")
    parser.add_argument("--test", action="append", dest="tests", help="Specific test(s) to run")
    parser.add_argument("--clean", action="store_true", help="Delete targeted_out before run")
    parser.add_argument("--update-baseline", action="store_true", help="Update signature baselines from current run")
    parser.add_argument("--list", action="store_true", help="List available tests and exit")
    args = parser.parse_args()

    all_names = [t["name"] for t in TESTS]
    if args.list:
        print("\n".join(all_names))
        return 0

    selected = TESTS
    if args.tests:
        unknown = [t for t in args.tests if t not in all_names]
        if unknown:
            print(f"Unknown tests: {', '.join(unknown)}", file=sys.stderr)
            return 2
        selected = [t for t in TESTS if t["name"] in set(args.tests)]

    if args.clean and OUT.exists():
        shutil.rmtree(OUT)

    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    COV_DIR.mkdir(parents=True, exist_ok=True)
    LOG_DIR.mkdir(parents=True, exist_ok=True)

    baselines = load_baselines()
    found_sigs: Dict[str, str] = {}

    failed: List[str] = []
    for idx, test in enumerate(selected, start=1):
        name = test["name"]
        print(f"[{idx}/{len(selected)}] {name}")
        ok, detail, sig = build_and_run(test)
        (LOG_DIR / f"{name}.log").write_text(detail + "\n", encoding="utf-8")
        if not ok:
            print(f"  FAIL: {name}")
            failed.append(name)
            continue

        if test["check_signature"]:
            if not sig:
                print(f"  FAIL: {name} (signature missing)")
                failed.append(name)
                continue
            found_sigs[name] = sig
            base = baselines.get(name)
            if args.update_baseline or base is None:
                print(f"  PASS: {name} (signature {sig}, baseline {'created' if base is None else 'updated'})")
            elif sig != base:
                print(f"  FAIL: {name} (signature mismatch: got {sig}, expected {base})")
                failed.append(name)
                continue
            else:
                print(f"  PASS: {name} (signature {sig})")
        else:
            print(f"  PASS: {name}")

    if args.update_baseline:
        for k, v in found_sigs.items():
            baselines[k] = v
        save_baselines(baselines)

    merged = merge_coverage()
    print("")
    print(f"Failed: {len(failed)}")
    if merged:
        print(f"Merged coverage: {merged}")
    else:
        print("Merged coverage: not available")

    if failed:
        print("\nFailure logs:")
        for name in failed:
            print(f"- {name}: {LOG_DIR / (name + '.log')}")
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
