# Session Handoff (2026-03-06)

## Current Branch / State
- Branch: `main`
- Working tree: clean at handoff time
- Last commits:
  - `4fed97a` Improve z80 ROI coverage and pass gate
  - `90c4cf5` Add ROI gate workflow and targeted regressions

## What Was Completed
- Added ROI gate CI workflow:
  - `.github/workflows/verilator-roi-gate.yml`
- Added ROI helpers and docs:
  - `tests/verilator/hotspot_roi_gate.py`
  - `tests/verilator/hotspot_delta.py` arg handling fixed (`--file` defaults + dedupe)
  - `tests/verilator/Makefile` (`targeted-snapshot`, `targeted-roi-gate`)
  - `tests/verilator/README.md` (local CI-equivalent ROI flow)
- Added targeted regressions:
  - `tb_ym7101_cachepaths_force_assert.sv`
  - `tb_m68k_irq_force_assert.sv`
  - `tb_z80_irq_force_assert.sv`

## Latest Verified Results
- Targeted run:
  - `python3 tests/verilator/run_targeted_regressions.py --clean`
  - Result: `22/22 PASS`
- ROI gate vs true `HEAD~1` baseline:
  - `ym7101.v`: `+90` uncovered
  - `68k.v`: `+8` uncovered
  - `z80.v`: `-2` uncovered
  - Gate result: `PASS` (improved `z80.v`)

## Fast Resume Commands
1. `git pull`
2. `python3 tests/verilator/run_targeted_regressions.py --clean`
3. Reproduce CI-equivalent ROI check:
   - Follow the `HEAD~1` worktree flow in `tests/verilator/README.md`
4. If needed, run:
   - `python3 tests/verilator/hotspot_delta.py <before.dat> tests/verilator/targeted_out/coverage/merged.dat --file ym7101.v --file 68k.v --file z80.v`

## Suggested Next Work Item
- Reduce regressions in `ym7101.v` and `68k.v` while keeping `z80.v` ROI improvement and gate pass.

