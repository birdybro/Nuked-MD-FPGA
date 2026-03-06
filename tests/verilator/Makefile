PYTHON ?= python3
RUNNER := run_verilator_tests.py
TARGETED := run_targeted_regressions.py

.PHONY: list smoke full targeted targeted-update targeted-list targeted-hotspots clean

list:
	$(PYTHON) $(RUNNER) --list-modules

smoke:
	$(PYTHON) $(RUNNER) --clean --cycles 64 --module ym3438 --module z80cpu --module md_board

full:
	$(PYTHON) $(RUNNER) --clean

targeted:
	$(PYTHON) $(TARGETED) --clean

targeted-update:
	$(PYTHON) $(TARGETED) --clean --update-baseline

targeted-list:
	$(PYTHON) $(TARGETED) --list

targeted-hotspots:
	$(PYTHON) coverage_hotspots.py targeted_out/coverage/merged.dat --top 20

targeted-snapshot:
	cp targeted_out/coverage/merged.dat /tmp/targeted_before.dat

targeted-roi-gate:
	$(PYTHON) hotspot_roi_gate.py /tmp/targeted_before.dat targeted_out/coverage/merged.dat

clean:
	rm -rf tests/verilator/out tests/verilator/targeted_out
