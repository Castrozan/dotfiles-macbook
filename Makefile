.PHONY: all test test-quick test-nix test-all help

all:

test: test-nix

test-quick:
	tests/run.sh --quick

test-nix:
	tests/run.sh --nix

test-all:
	tests/run.sh --nix

help:
	@echo "Available targets:"
	@echo "  make test           - Run nix tests: quick + nix eval (default)"
	@echo "  make test-quick     - Run quick tests only (skill validation + bin scripts)"
	@echo "  make test-nix       - Run quick + nix eval tests"
	@echo "  make test-all       - Run all tests"
