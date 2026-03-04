PYTHON ?= python3
RUNNER := run_verilator_tests.py
TARGETED := run_targeted_regressions.py

.PHONY: list smoke full targeted targeted-update targeted-list clean

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

clean:
	rm -rf tests/verilator/out tests/verilator/targeted_out
