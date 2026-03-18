#!/usr/bin/env bash

set -Eeuo pipefail

[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0

readonly REPO_ROOT=$(git rev-parse --show-toplevel)

[[ "$(basename "$REPO_ROOT")" != ".dotfiles" ]] && exit 0

cd "$REPO_ROOT"

main() {
	_run_check "statix" nix run nixpkgs#statix -- check . --ignore 'result*'
	_run_check "deadnix" nix run nixpkgs#deadnix -- .
	_run_check "nixfmt" bash -c "find . -name '*.nix' -not -path './result*' -not -path './.worktrees/*' -exec nix run nixpkgs#nixfmt-rfc-style -- --check {} +"
	_run_check "validate-skill-frontmatter" ./agents/evals/validate-skill-frontmatter.sh agents/skills
	_run_quick_bats_tests

	echo "All pre-push checks passed."
}

_run_check() {
	local checkName="$1"
	shift
	echo "==> $checkName"
	"$@"
	echo ""
}

_run_quick_bats_tests() {
	echo "==> bats (quick)"
	local testFiles
	testFiles=$(find home/modules -path "*/tests/*.bats" -type f | sort)
	nix shell nixpkgs#bats --command bats $testFiles
	echo ""
}

main "$@"
