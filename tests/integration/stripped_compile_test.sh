set -euo pipefail
[ -z "$TEST_SRCDIR" ] && { echo "TEST_SRCDIR not set!" >&2; exit 1; }

source "$(rlocation "rules_cc/tests/integration/test_utils.sh")"

bazel build //:hello.stripped >& "$TEST_log" || fail "Build failed"
bazel-bin/hello.stripped >> "$TEST_log"
expect_log "Hit me baby one more time!"
