#!/usr/bin/env bash
#
# Self-test for check-diagnostic-discipline.sh. Each fixture under
# fixtures/ is a tiny tree containing a violation we expect the gate
# to surface. The driver runs the production script against each
# fixture (via DIAGRAMKIT_DISCIPLINE_ROOT) and asserts the expected
# exit code.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$ROOT/Scripts/check-diagnostic-discipline.sh"

# The gate requires bash 4+ (associative-array allowlist; it exits 2 under
# stock /bin/bash 3.2 rather than fail open). Resolve a suitable interpreter
# so this harness also works when invoked from bash 3.2.
GATE_BASH=""
if command -v bash >/dev/null 2>&1; then
  if [[ "$(bash -c 'echo ${BASH_VERSINFO[0]}')" -ge 4 ]]; then
    GATE_BASH="bash"
  fi
fi
if [[ -z "$GATE_BASH" ]]; then
  for candidate in /opt/homebrew/bin/bash /usr/local/bin/bash /opt/local/bin/bash; do
    if [[ -x "$candidate" ]]; then
      GATE_BASH="$candidate"
      break
    fi
  done
fi
if [[ -z "$GATE_BASH" ]]; then
  echo "diagnostic-discipline self-test: requires bash 4+" >&2
  exit 2
fi

FAILED=0

run_fixture() {
  local name="$1"
  local expected_exit="$2"

  local sandbox
  sandbox=$(mktemp -d)

  # Fixtures carry their own Sources/ tree.
  cp -R "$HERE/fixtures/$name/." "$sandbox/"
  mkdir -p "$sandbox/Tests"
  # Empty allowlist in the sandbox so we exercise the unallowlisted path.
  touch "$sandbox/.diagnostic-discipline-allowlist.txt"

  set +e
  DIAGRAMKIT_DISCIPLINE_ROOT="$sandbox" "$GATE_BASH" "$GATE" >/dev/null 2>&1
  local actual=$?
  set -e

  rm -rf "$sandbox"

  if [[ "$actual" -eq "$expected_exit" ]]; then
    echo "  ✓ $name (exit $actual)"
  else
    echo "  ✗ $name expected exit $expected_exit, got $actual" >&2
    FAILED=$((FAILED + 1))
  fi
}

echo "diagnostic-discipline self-test:"
run_fixture "bad-raw-init" 1
run_fixture "bad-missing-pinned" 1
run_fixture "bad-stale-pinned" 1
run_fixture "bad-exporter-throws" 1
run_fixture "bad-export-dir-throws" 1
run_fixture "good-clean" 0

if [[ "$FAILED" -gt 0 ]]; then
  echo "diagnostic-discipline self-test: $FAILED fixture(s) failed" >&2
  exit 1
fi
echo "diagnostic-discipline self-test: ✓ all fixtures passed"
exit 0
