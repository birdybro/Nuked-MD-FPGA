# Verilator Coverage Harness

This directory contains an automated Verilator smoke-test and coverage flow for all Verilog modules in the repository.

## What it does

- Discovers modules from top-level `*.v` files.
- Generates a temporary SystemVerilog smoke testbench per module.
- Builds each generated testbench with Verilator `--coverage`.
- Runs each simulation and writes one coverage data file per module.
- Merges all module coverage files into one `merged.dat`.
- Supports targeted assertion and vector regressions with signature checking.

## Quick start

```bash
python3 tests/verilator/run_verilator_tests.py --clean
```

## Useful commands

List discovered modules:

```bash
python3 tests/verilator/run_verilator_tests.py --list-modules
```

Run a single module:

```bash
python3 tests/verilator/run_verilator_tests.py --clean --module ym3438
```

Run selected modules:

```bash
python3 tests/verilator/run_verilator_tests.py --module ym3438 --module ym7101 --module md_board
```

Increase/decrease stimulus length:

```bash
python3 tests/verilator/run_verilator_tests.py --cycles 1024
```

Run targeted assertion/vector regressions:

```bash
python3 tests/verilator/run_targeted_regressions.py --clean
```

Initialize or refresh targeted vector signature baselines:

```bash
python3 tests/verilator/run_targeted_regressions.py --clean --update-baseline
```

List targeted tests:

```bash
python3 tests/verilator/run_targeted_regressions.py --list
```

Run one targeted test:

```bash
python3 tests/verilator/run_targeted_regressions.py --test ym6046_vector
```

Show top uncovered files from merged targeted coverage:

```bash
python3 tests/verilator/coverage_hotspots.py tests/verilator/targeted_out/coverage/merged.dat --top 20
```

Compare hotspot deltas between two merged coverage datasets:

```bash
python3 tests/verilator/hotspot_delta.py /tmp/targeted_before.dat tests/verilator/targeted_out/coverage/merged.dat
```

Gate ROI (fail if none of `ym7101.v` / `68k.v` / `z80.v` improve):

```bash
python3 tests/verilator/hotspot_roi_gate.py /tmp/targeted_before.dat tests/verilator/targeted_out/coverage/merged.dat
```

Reproduce the CI ROI check locally (`HEAD~1` baseline vs current `HEAD`):

```bash
tmp_prev=$(mktemp -d /tmp/nuked-prev-XXXXXX)
git worktree add "$tmp_prev" HEAD~1
(
  cd "$tmp_prev"
  python3 tests/verilator/run_targeted_regressions.py --clean
  cp tests/verilator/targeted_out/coverage/merged.dat /tmp/targeted_before_head_prev.dat
)
python3 tests/verilator/run_targeted_regressions.py --clean
python3 tests/verilator/hotspot_roi_gate.py \
  /tmp/targeted_before_head_prev.dat \
  tests/verilator/targeted_out/coverage/merged.dat \
  --file ym7101.v --file 68k.v --file z80.v
git worktree remove "$tmp_prev"
rmdir "$tmp_prev" 2>/dev/null || true
```

Makefile helpers for ROI workflow:

```bash
make -C tests/verilator targeted-snapshot
make -C tests/verilator targeted-roi-gate
```

## Output layout

- Generated testbenches: `tests/verilator/out/tb/`
- Verilator build artifacts: `tests/verilator/out/build/`
- Coverage data files: `tests/verilator/out/coverage/`
- Merged coverage file: `tests/verilator/out/coverage/merged.dat`
- Targeted regression artifacts: `tests/verilator/targeted_out/`

## Notes

- This is a broad smoke/coverage harness, not a behavioral golden-model verification suite.
- The generated tests randomize non-clock inputs and pulse reset-like signals for early cycles.
- Verilator warnings are allowed (`-Wno-fatal`) so legacy warnings do not block coverage collection.
- Targeted regressions add hard assertions and deterministic vector replay for higher-confidence behavioral checks.
- Current targeted set includes:
  - `tmss_assert`
  - `ym3438_prescaler_assert`
  - `ym3438_io_vector`
  - `tmss_bus_transaction`
  - `tmss_vector`
  - `ym6046_vector`
  - `ym7101_vector`
  - `ym7101_dma_vector`
  - `ym7101_stress_assert`
  - `ym7101_dma_arb_assert`
  - `ym7101_dma_edge_assert`
  - `ym7101_cachepaths_force_assert`
  - `m68k_vector`
  - `m68k_exceptions_vector`
  - `m68k_bus_arb_assert`
  - `m68k_irq_entry_assert`
  - `m68k_irq_force_assert`
  - `ym6045_vector`
  - `z80_irq_force_assert`
  - `z80_bus_vector`
  - `z80_instr_vector`
  - `md_board_cart_vector`
