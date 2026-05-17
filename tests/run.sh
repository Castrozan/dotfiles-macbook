#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

main() {
	local selectedMode="quick"

	_parse_arguments "$@"

	echo "=== Running Tests (${selectedMode}) ==="
	echo ""

	case "$selectedMode" in
	quick) _run_quick_tier ;;
	nix)
		_run_quick_tier
		_run_nix_tier
		;;
	all)
		_run_quick_tier
		_run_nix_tier
		;;
	evals) _run_evals_tier ;;
	esac

	echo "=== All Tests Complete ==="
}

_parse_arguments() {
	while [[ $# -gt 0 ]]; do
		case $1 in
		--quick)
			selectedMode="quick"
			shift
			;;
		--nix)
			selectedMode="nix"
			shift
			;;
		--all)
			selectedMode="all"
			shift
			;;
		--evals)
			selectedMode="evals"
			shift
			;;
		*)
			echo "Unknown option: $1" >&2
			exit 1
			;;
		esac
	done
}

_run_quick_tier() {
	_run_skill_frontmatter_validation
	_run_quick_bats_tests
	_run_quick_pytest_tests
	_run_swift_logic_tests
}

_run_nix_tier() {
	_run_nix_flake_checks
}

_run_evals_tier() {
	if ! command -v claude &>/dev/null; then
		echo "SKIP: claude CLI not installed, skipping agent evals" >&2
		return 0
	fi

	echo "--- Agent Evals (LLM) ---"
	"$REPO_DIR/agents/evals/run-evals.py"
	echo ""
}

_collect_quick_pytest_test_files() {
	find "$REPO_DIR/home/modules" "$REPO_DIR/agents/hooks" -path "*/tests/test_*.py" -type f | sort
}

_run_quick_pytest_tests() {
	if ! command -v pytest &>/dev/null; then
		echo "WARN: pytest not installed, skipping python tests" >&2
		return 0
	fi

	local testFiles
	testFiles=$(_collect_quick_pytest_test_files)
	if [[ -z "$testFiles" ]]; then
		return 0
	fi

	echo "--- Python Tests (quick) ---"
	pytest $testFiles -x -q
	echo ""
}

_run_swift_logic_tests() {
	local swiftSourcesDir="$REPO_DIR/hosts/macbook/scripts/workspace-window-switcher-daemon-swift-sources"

	if [[ ! -d "$swiftSourcesDir" ]]; then
		return 0
	fi
	if ! command -v /usr/bin/swiftc &>/dev/null; then
		echo "WARN: /usr/bin/swiftc not available, skipping swift logic tests" >&2
		return 0
	fi

	echo "--- Swift Logic Tests (workspace-window-switcher-daemon) ---"
	local testBinary
	testBinary="$(mktemp -t wws-tests.XXXXXX)"
	local swiftSourceFiles=()
	while IFS= read -r -d '' swiftSourceFile; do
		swiftSourceFiles+=("$swiftSourceFile")
	done < <(/usr/bin/find "$swiftSourcesDir" -name "*.swift" -not -name "main.swift" -print0)
	/usr/bin/swiftc -O -o "$testBinary" "${swiftSourceFiles[@]}"
	"$testBinary"
	rm -f "$testBinary"
	echo ""
}

_run_skill_frontmatter_validation() {
	echo "--- Skill Frontmatter Validation ---"
	"$REPO_DIR/agents/evals/validate-skill-frontmatter.sh" "$REPO_DIR/agents/skills"
	echo ""
}

_collect_quick_bats_test_files() {
	find "$REPO_DIR/home/modules" -path "*/tests/*.bats" -type f | sort
}

_run_quick_bats_tests() {
	if ! command -v bats &>/dev/null; then
		echo "WARN: bats not installed, skipping bin script tests" >&2
		echo "      Install with: nix shell nixpkgs#bats" >&2
		return 0
	fi

	echo "--- Bin Script Tests (quick) ---"
	local testFiles
	testFiles=$(_collect_quick_bats_test_files)
	bats $testFiles
	echo ""
}

_detect_current_system() {
	local arch
	arch="$(uname -m)"

	if [[ "$arch" == "arm64" ]]; then
		arch="aarch64"
	fi

	echo "${arch}-darwin"
}

_run_nix_flake_checks() {
	if ! command -v nix &>/dev/null; then
		echo "WARN: nix not installed, skipping nix flake checks" >&2
		return 0
	fi

	local currentSystem
	currentSystem="$(_detect_current_system)"

	echo "--- Nix Flake Checks (${currentSystem}) ---"
	local checkNames
	checkNames=$(nix eval ".#checks.${currentSystem}" --apply 'builtins.attrNames' --json 2>/dev/null | jq -r '.[]')
	local failedChecks=0
	for checkName in $checkNames; do
		if nix build ".#checks.${currentSystem}.${checkName}" --no-link --print-build-logs 2>&1; then
			echo "  PASS: ${checkName}"
		else
			echo "  FAIL: ${checkName}"
			failedChecks=$((failedChecks + 1))
		fi
	done
	if [[ "$failedChecks" -gt 0 ]]; then
		echo "FAILED: ${failedChecks} check(s) failed"
		return 1
	fi
	echo ""
}

main "$@"
