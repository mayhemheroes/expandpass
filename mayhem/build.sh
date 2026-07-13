#!/usr/bin/env bash
#
# mayhem/build.sh — build the expandpass fuzz target and the functional-test binary.
#
# expandpass is a single-translation-unit C++ CLI (gen.cpp #includes everything under src/)
# that expands a password-seed grammar file: `expandpass -i <seedfile>`. The CLI itself is the
# Mayhem target (the archived original fuzzed `./expandpass -i @@`), so we build it two ways:
#   build/expandpass   sanitized (ASan+UBSan, halting) + DWARF-3  -> the Mayhem target
#   ./expandpass       normal flags                               -> tests/run.sh's binary,
#                                                                    run by mayhem/test.sh
# Everything comes from upstream sources; no network, no upstream edits.
set -euo pipefail

# clang rejects SOURCE_DATE_EPOCH='' (empty) — it must be unset or a valid integer.
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

# Build knobs from the environment (base image exports the defaults); fall back for a bare run.
: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CXX:=clang++}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS CXX MAYHEM_JOBS COVERAGE_FLAGS

cd "${SRC:-/mayhem}"

# -Wno-write-strings matches upstream's makefile (NOWARN); the code assigns string literals to
# char*. gen.cpp is the upstream single-TU entry point.

# 1) Sanitized fuzz target — the PROJECT ITSELF is instrumented, so ASan/UBSan see bugs in the
#    parser/expander. -O1 keeps frames readable; $DEBUG_FLAGS after the sanitizer flags so
#    -gdwarf-3 wins (DWARF must be < 4 for Mayhem triage).
#    mayhem/asan_options.c disables LeakSanitizer only (allocate-and-exit batch tool: LSan flags
#    every input AND its exit-time ptrace attach dies under Mayhem's tracer → 0 edges); compiled
#    as C so the option hooks keep C linkage.
mkdir -p build
: "${CC:=clang}"
# shellcheck disable=SC2086
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -c mayhem/asan_options.c -o build/asan_options.o
# shellcheck disable=SC2086
$CXX $SANITIZER_FLAGS $DEBUG_FLAGS -O1 -Wno-write-strings gen.cpp build/asan_options.o -o build/expandpass

# 2) Clean test build (NO sanitizers), at the repo root where tests/run.sh expects it
#    (../expandpass relative to tests/), so mayhem/test.sh only RUNS the upstream suite.
#    $COVERAGE_FLAGS is empty by default (a coverage build appends it here).
# shellcheck disable=SC2086
$CXX -O2 $COVERAGE_FLAGS -Wno-write-strings gen.cpp -o ./expandpass

echo "build.sh: built build/expandpass (sanitized fuzz target) and ./expandpass (test binary)"
