#!/usr/bin/env python3
"""Auto-generate Verilator smoke tests and collect merged coverage."""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Dict, List

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "tests" / "verilator" / "out"
TB_DIR = OUT / "tb"
BUILD_DIR = OUT / "build"
COV_DIR = OUT / "coverage"
LOG_DIR = OUT / "logs"

MODULE_RE = re.compile(r"^\s*module\s+([A-Za-z_][A-Za-z0-9_]*)")
CLOCK_RE = re.compile(r"clk|clock", re.IGNORECASE)
RESET_RE = re.compile(r"(?:^|_)(?:reset|res|rst|sres|wres|zres|vres|fres)(?:$|_)", re.IGNORECASE)
ACTIVE_LOW_RESET_RE = re.compile(r"(?:_n$|_b$|^n(?:reset|res|rst)$|(?:reset|res|rst)_n$)", re.IGNORECASE)

EXCLUDED_MODULES = {
    "MD_Run",  # Icarus-specific testbench.
    "ram_68k",
    "ram_z80",
    "vram_ip",
}


def run(cmd: List[str], cwd: Path | None = None, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=cwd, check=check, text=True, capture_output=True)


def source_files() -> List[Path]:
    files = sorted(ROOT.glob("*.v"))
    # Include simple memory stubs so wrappers like vram_ip resolve under Verilator.
    memstubs = ROOT / "icarus" / "memstubs.v"
    if memstubs.exists():
        files.append(memstubs)
    return files


def discover_modules() -> List[str]:
    mods: List[str] = []
    for src in source_files():
        text = src.read_text(encoding="utf-8", errors="ignore")
        for line in text.splitlines():
            m = MODULE_RE.match(line)
            if m:
                name = m.group(1)
                if name not in EXCLUDED_MODULES:
                    mods.append(name)
    # Preserve declaration order but dedupe.
    seen = set()
    ordered = []
    for m in mods:
        if m not in seen:
            seen.add(m)
            ordered.append(m)
    return ordered


def parse_typetable(root: ET.Element) -> Dict[str, int]:
    widths: Dict[str, int] = {}
    typetable = root.find(".//typetable")
    if typetable is None:
        return widths

    # First pass for simple dtypes.
    for node in typetable:
        dtype_id = node.attrib.get("id")
        if not dtype_id:
            continue
        if node.tag == "basicdtype":
            left = node.attrib.get("left")
            right = node.attrib.get("right")
            if left is None or right is None:
                widths[dtype_id] = 1
            else:
                widths[dtype_id] = abs(int(left) - int(right)) + 1

    # Best-effort for packed arrays.
    unresolved = True
    while unresolved:
        unresolved = False
        for node in typetable:
            if node.tag not in {"packarraydtype", "unpackarraydtype"}:
                continue
            dtype_id = node.attrib.get("id")
            sub_id = node.attrib.get("sub_dtype_id")
            if not dtype_id or dtype_id in widths or not sub_id or sub_id not in widths:
                continue

            left = node.attrib.get("left")
            right = node.attrib.get("right")
            if left is None or right is None:
                # Some XML forms store bounds as child consts; fallback to scalar multiplier.
                widths[dtype_id] = widths[sub_id]
                continue
            mul = abs(int(left) - int(right)) + 1
            widths[dtype_id] = widths[sub_id] * mul
            unresolved = True

    return widths


def parse_ports(xml_file: Path, module: str) -> List[dict]:
    tree = ET.parse(xml_file)
    root = tree.getroot()
    widths = parse_typetable(root)

    top = None
    for mod in root.findall(".//module"):
        if mod.attrib.get("name") == module and mod.attrib.get("topModule") == "1":
            top = mod
            break
    if top is None:
        raise RuntimeError(f"Top module {module} not found in {xml_file}")

    ports: List[dict] = []
    for var in top.findall("var"):
        d = var.attrib.get("dir")
        if d not in {"input", "output", "inout"}:
            continue
        name = var.attrib["name"]
        dtype_id = var.attrib.get("dtype_id", "")
        width = widths.get(dtype_id, 1)
        ports.append({"name": name, "dir": d, "width": max(1, width)})
    return ports


def sv_decl(sig_type: str, name: str, width: int) -> str:
    if width <= 1:
        return f"{sig_type} {name};"
    return f"{sig_type} [{width - 1}:0] {name};"


def rand_expr(width: int, seed: str) -> str:
    chunks = (width + 31) // 32
    if chunks <= 1:
        return f"$urandom({seed})"
    return "{" + ", ".join([f"$urandom({seed})" for _ in range(chunks)]) + "}"


def const_expr(width: int, bit: int) -> str:
    if width == 1:
        return "1'b1" if bit else "1'b0"
    return "{" + f"{width}" + "{" + ("1'b1" if bit else "1'b0") + "}}"


def generate_tb(module: str, ports: List[dict], cycles: int) -> Path:
    tb_name = f"tb_{module}"
    tb_file = TB_DIR / f"{tb_name}.sv"

    inputs = [p for p in ports if p["dir"] == "input"]
    outputs = [p for p in ports if p["dir"] == "output"]
    inouts = [p for p in ports if p["dir"] == "inout"]

    clocks = [p for p in inputs if CLOCK_RE.search(p["name"]) and not RESET_RE.search(p["name"])]
    driven_inputs = [p for p in inputs if p not in clocks]

    lines: List[str] = []
    lines.append("`timescale 1ns/1ps")
    lines.append(f"module {tb_name};")
    lines.append("")

    for p in inputs:
        lines.append("  " + sv_decl("logic", p["name"], p["width"]))
    for p in outputs:
        lines.append("  " + sv_decl("wire", p["name"], p["width"]))
    for p in inouts:
        lines.append("  " + sv_decl("tri", p["name"], p["width"]))

    lines.append("")
    lines.append(f"  {module} dut (")
    for idx, p in enumerate(ports):
        comma = "," if idx != len(ports) - 1 else ""
        lines.append(f"    .{p['name']}({p['name']}){comma}")
    lines.append("  );")
    lines.append("")

    for p in clocks:
        lines.append(f"  initial {p['name']} = 1'b0;")
        lines.append(f"  always #1 {p['name']} = ~{p['name']};")
    if clocks:
        lines.append("")

    lines.append("  integer i;")
    lines.append("  integer seed;")
    lines.append("  initial begin")
    lines.append("    seed = 32'h1badf00d;")

    for p in driven_inputs:
        lines.append(f"    {p['name']} = '0;")
    lines.append("    #2;")

    lines.append(f"    for (i = 0; i < {cycles}; i = i + 1) begin")
    for p in driven_inputs:
        name = p["name"]
        width = p["width"]
        if RESET_RE.search(name):
            bit = 0 if ACTIVE_LOW_RESET_RE.search(name) else 1
            asserted = const_expr(width, bit)
            lines.append(f"      {name} = (i < 8) ? {asserted} : {rand_expr(width, 'seed')};")
        else:
            lines.append(f"      {name} = {rand_expr(width, 'seed')};")
    lines.append("      #2;")
    lines.append("    end")

    lines.append(f"    $display(\"{tb_name}: completed {cycles} cycles\");")
    lines.append("    $finish;")
    lines.append("  end")
    lines.append("endmodule")

    tb_file.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return tb_file


def generate_main_cpp(module: str, coverage_file: Path) -> Path:
    tb_name = f"tb_{module}"
    cpp_file = OUT / f"{tb_name}_main.cpp"
    lines = [
        '#include "verilated.h"',
        '#include "verilated_cov.h"',
        f'#include "V{tb_name}.h"',
        "",
        "static vluint64_t main_time = 0;",
        "double sc_time_stamp() { return static_cast<double>(main_time); }",
        "",
        "int main(int argc, char** argv) {",
        "    Verilated::commandArgs(argc, argv);",
        f"    auto* top = new V{tb_name};",
        "    while (!Verilated::gotFinish()) {",
        "        top->eval();",
        "        ++main_time;",
        "    }",
        f'    VerilatedCov::write("{coverage_file}");',
        "    delete top;",
        "    return 0;",
        "}",
    ]
    cpp_file.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return cpp_file


def build_and_run(module: str, cycles: int) -> tuple[bool, str]:
    srcs = [str(p) for p in source_files()]
    xml_path = OUT / f"{module}.xml"
    tb_name = f"tb_{module}"

    xml_cmd = [
        "verilator",
        "-Wno-fatal",
        "--xml-only",
        "--xml-output",
        str(xml_path),
        "--top-module",
        module,
        *srcs,
    ]
    xml_res = run(xml_cmd, cwd=ROOT, check=False)
    if xml_res.returncode != 0:
        return False, f"xml generation failed\n{xml_res.stderr}"

    try:
        ports = parse_ports(xml_path, module)
    except Exception as exc:  # pylint: disable=broad-except
        return False, f"xml parse failed: {exc}"

    tb_file = generate_tb(module, ports, cycles)
    mdir = BUILD_DIR / module
    mdir.mkdir(parents=True, exist_ok=True)
    cov_file = COV_DIR / f"{module}.dat"
    main_cpp = generate_main_cpp(module, cov_file)

    build_cmd = [
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
        tb_name,
        str(tb_file),
        str(main_cpp),
        *srcs,
    ]
    build_res = run(build_cmd, cwd=ROOT, check=False)
    if build_res.returncode != 0:
        return False, f"build failed\nSTDOUT:\n{build_res.stdout}\nSTDERR:\n{build_res.stderr}"

    exe = mdir / f"V{tb_name}"
    if not exe.exists():
        return False, f"binary missing: {exe}"

    run_res = run([str(exe)], cwd=ROOT, check=False)
    if run_res.returncode != 0:
        return False, f"run failed\nSTDOUT:\n{run_res.stdout}\nSTDERR:\n{run_res.stderr}"

    if not cov_file.exists():
        return False, f"coverage file missing: {cov_file}"

    return True, "ok"


def merge_coverage() -> Path | None:
    cov_files = sorted(COV_DIR.glob("*.dat"))
    if not cov_files:
        return None
    merged = COV_DIR / "merged.dat"
    cmd = ["verilator_coverage", "--write", str(merged), *[str(f) for f in cov_files]]
    res = run(cmd, cwd=ROOT, check=False)
    if res.returncode != 0:
        print("[WARN] Failed to merge coverage with verilator_coverage", file=sys.stderr)
        print(res.stderr, file=sys.stderr)
        return None
    return merged


def main() -> int:
    parser = argparse.ArgumentParser(description="Run auto-generated Verilator smoke tests with coverage.")
    parser.add_argument("--cycles", type=int, default=512, help="Stimulus cycles per module")
    parser.add_argument("--module", action="append", dest="modules", help="Specific module(s) to run")
    parser.add_argument("--list-modules", action="store_true", help="List discovered modules and exit")
    parser.add_argument("--clean", action="store_true", help="Remove output directory before running")
    args = parser.parse_args()

    modules = discover_modules()
    if args.list_modules:
        print("\n".join(modules))
        return 0

    selected = args.modules if args.modules else modules
    unknown = [m for m in selected if m not in modules]
    if unknown:
        print(f"Unknown modules: {', '.join(unknown)}", file=sys.stderr)
        return 2

    if args.clean and OUT.exists():
        shutil.rmtree(OUT)

    TB_DIR.mkdir(parents=True, exist_ok=True)
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    COV_DIR.mkdir(parents=True, exist_ok=True)
    LOG_DIR.mkdir(parents=True, exist_ok=True)

    total = len(selected)
    passed = 0
    failed: List[tuple[str, str]] = []

    for idx, mod in enumerate(selected, start=1):
        print(f"[{idx}/{total}] {mod}")
        ok, info = build_and_run(mod, args.cycles)
        if ok:
            passed += 1
            print(f"  PASS: {mod}")
        else:
            failed.append((mod, info))
            (LOG_DIR / f"{mod}.log").write_text(info + "\n", encoding="utf-8")
            print(f"  FAIL: {mod}")

    merged = merge_coverage()
    print("")
    print(f"Passed: {passed}/{total}")
    print(f"Failed: {len(failed)}")
    if merged:
        print(f"Merged coverage: {merged}")
    else:
        print("Merged coverage: not available")

    if failed:
        print("\nFailure details:")
        for mod, detail in failed:
            print(f"- {mod}: {detail.splitlines()[0]}")
            print(f"  log: {LOG_DIR / f'{mod}.log'}")
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
