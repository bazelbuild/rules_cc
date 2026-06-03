set -euo pipefail
[ -z "$TEST_SRCDIR" ] && { echo "TEST_SRCDIR not set!" >&2; exit 1; }

source "$(rlocation rules_cc/tests/integration/test_utils.sh)"

bazel build -s //:hello >& "$TEST_log" || fail "Build failed"
expect_log "Compiling hello.cc"
bazel shutdown
bazel build -s //:hello >& "$TEST_log" || fail "Build failed"
expect_not_log "Compiling hello.cc"
