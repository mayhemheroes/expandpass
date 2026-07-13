/* Disable LeakSanitizer only (keep ASan + UBSan).
 *
 * expandpass is an allocate-and-exit batch tool: it mallocs its expansion buffers and exits
 * without freeing, so LSan reports leaks on EVERY input. Worse, Mayhem runs the target under
 * ptrace for coverage, and LSan's own exit-time ptrace attach then fails ("does not work under
 * ptrace") — the process exits before any edges are recorded (0-edge "Run Failed"). Turning LSan
 * off keeps the high-value detectors (ASan OOB/UAF, UBSan) and lets the target accumulate coverage.
 * Strong (non-weak) symbols so they always beat the sanitizer runtime's defaults. */
const char *__asan_default_options(void) { return "detect_leaks=0"; }
const char *__lsan_default_options(void) { return "detect_leaks=0"; }
