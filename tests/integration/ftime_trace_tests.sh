set -euo pipefail

source "$(rlocation rules_cc/tests/test_utils.sh)"
source "$(rlocation rules_cc/tests/unittest.bash)"

function set_up() {
  if is_windows; then
    echo "Skipping on Windows."
    return 1
  fi

  local -r clang="$(which clang || true)"
  local -r clangxx="$(which clang++ || true)"
  if [[ ! -x "$clang" || ! -x "$clangxx" ]]; then
    echo "clang/clang++ not installed. Skipping test."
    return 1
  fi

  add_to_bazelrc "common --repo_env=CC=$clang"
  add_to_bazelrc "common --repo_env=CXX=$clangxx"
}

function test_ftime_trace_outputs() {
  # Bazel versions before 9 use the built-in native C++ rules, not rules_cc.
  # This integration test exercises the rules_cc -ftime-trace implementation only.
  local bazel_version=""
  bazel_version="$(bazel version 2>/dev/null | awk '/^(Build label|Release label):/ { print $3; exit }')"
  local bazel_major="${bazel_version%%.*}"
  if [[ -z "$bazel_major" || "$bazel_major" -lt 9 ]]; then
    echo "Bazel ${bazel_version:-unknown} is older than 9.0; native C++ rules are used instead of rules_cc. Skipping test."
    return 0
  fi

  cat > BUILD << EOF
load("@rules_cc//cc:cc_library.bzl", "cc_library")

cc_library(
    name = "lib_with_trace",
    srcs = ["foo.cc"],
    features = ["trace"],
)
EOF

  cat > foo.cc << EOF
int foo() {
  return 42;
}
EOF

  bazel build //:lib_with_trace --output_groups=trace_files >& "$TEST_log" || fail "Build failed"

  trace_json="$(find bazel-bin/_objs/lib_with_trace -name '*.json' | head -1)"
  if [[ -z "$trace_json" ]]; then
    fail "Expected a Clang -ftime-trace JSON file under bazel-bin/_objs/lib_with_trace"
  fi

  if [[ ! -s "$trace_json" ]]; then
    fail "Trace file is empty: $trace_json"
  fi

  python3 - "$trace_json" << 'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as input_file:
    data = json.load(input_file)

if "traceEvents" not in data:
    raise SystemExit(f"missing traceEvents key in {path}")
if not isinstance(data["traceEvents"], list) or not data["traceEvents"]:
    raise SystemExit(f"traceEvents is empty in {path}")
PY
}

run_suite "Integration tests for Clang -ftime-trace with rules_cc"
