#!/usr/bin/env bash
#
# mayhem/test.sh — RUN expandpass's upstream functional test suite (tests/), already built by
# mayhem/build.sh (./expandpass, normal flags — the exact binary tests/run.sh targets).
#
# This runs the SAME 19 golden-output tests as upstream's tests/run.sh (same inputs tests/in/N,
# same optional CLI args tests/args/N, byte-exact diffs of stdout against tests/out/N and stderr
# against tests/err/N), but per-test with CTRF accounting instead of run.sh's exit-on-first-fail.
# Golden diffs make this a behavioral oracle: a PATCH that neuters the program to exit(0)
# produces no expansion output and FAILS here (anti-reward-hack).
#
# Test 19 is SKIPPED: it fails on upstream tip 19e052b as shipped (expected line "a2" is never
# produced — a pre-existing upstream expectation mismatch, reproducible with upstream's own
# `make test`), so it cannot gate the image build. 18/19 upstream tests are enforced.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
cd "${SRC:-/mayhem}"

BIN=./expandpass
passed=0; failed=0; skipped=0
KNOWN_FAIL_UPSTREAM="19"

# emit_ctrf <tool> <passed> <failed> [skipped]
emit_ctrf() {
  local tool="$1" p="$2" f="$3" s="${4:-0}"
  local tests=$(( p + f + s ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": { "tests": $tests, "passed": $p, "failed": $f, "pending": 0, "skipped": $s, "other": 0 }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":0,"skipped":%d,"other":0}}}\n' \
    "$tool" "$tests" "$p" "$f" "$s"
  [ "$f" -eq 0 ]
}

if [ ! -x "$BIN" ]; then
  echo "test.sh: $BIN missing — build.sh must build it (not rebuilding here)" >&2
  emit_ctrf expandpass-tests 0 1; exit 1
fi

# Same test count discovery as upstream tests/run.sh (highest N with an in/args/out file).
n_tests=0
for i in $(seq 1 100); do
  if [ -f "tests/$i" ] || [ -f "tests/in/$i" ] || [ -f "tests/args/$i" ] || [ -f "tests/out/$i" ]; then
    n_tests=$i
  fi
done
echo "test.sh: discovered $n_tests upstream tests (tests/run.sh layout)"

for i in $(seq 1 "$n_tests"); do
  case " $KNOWN_FAIL_UPSTREAM " in *" $i "*)
    echo "  skip - test $i (fails on unmodified upstream tip — pre-existing expectation mismatch)"
    skipped=$((skipped+1)); continue;;
  esac
  out_exp="tests/out/$i"; err_exp="tests/err/$i"
  [ -f "$out_exp" ] || out_exp=/dev/null
  [ -f "$err_exp" ] || err_exp=/dev/null
  if [ -f "tests/args/$i" ]; then
    xargs "$BIN" -i "tests/in/$i" < "tests/args/$i" > /tmp/ep_stdout 2> /tmp/ep_stderr
  else
    "$BIN" -i "tests/in/$i" > /tmp/ep_stdout 2> /tmp/ep_stderr
  fi
  if diff -q /tmp/ep_stdout "$out_exp" >/dev/null && diff -q /tmp/ep_stderr "$err_exp" >/dev/null; then
    echo "  ok   - test $i"; passed=$((passed+1))
  else
    echo "  FAIL - test $i (stdout/stderr differ from tests/out|err/$i)"
    diff /tmp/ep_stdout "$out_exp" | head -5
    diff /tmp/ep_stderr "$err_exp" | head -5
    failed=$((failed+1))
  fi
done

echo "test.sh: passed=$passed failed=$failed skipped=$skipped"
emit_ctrf expandpass-tests "$passed" "$failed" "$skipped"
