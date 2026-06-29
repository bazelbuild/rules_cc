set -euo pipefail

source "$(rlocation rules_cc/tests/test_utils.sh)"
source "$(rlocation rules_cc/tests/unittest.bash)"

function test_cc_static_library_duplicate_symbol() {
  mkdir -p pkg
  cat > pkg/BUILD<<'EOF'
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc:cc_static_library.bzl", "cc_static_library")
cc_static_library(
    name = "static",
    deps = [
        ":direct1",
        ":direct2",
    ],
)
cc_library(
    name = "direct1",
    srcs = ["direct1.cc"],
)
cc_library(
    name = "direct2",
    srcs = ["direct2.cc"],
    deps = [":indirect"],
)
cc_library(
    name = "indirect",
    srcs = ["indirect.cc"],
)
EOF
  cat > pkg/direct1.cc<<'EOF'
int foo() { return 42; }
EOF
  cat > pkg/direct2.cc<<'EOF'
int bar() { return 21; }
EOF
  cat > pkg/indirect.cc<<'EOF'
int foo() { return 21; }
EOF

  bazel build //pkg:static \
    &> $TEST_log && fail "Expected build to fail"
  if is_windows; then
    expect_log "direct1.obj"
    expect_log "indirect.obj"
    expect_log " foo("
  elif is_darwin; then
    expect_log "Duplicate symbols found in .*/pkg/libstatic.a:"
    expect_log "direct1.o: T foo()"
    expect_log "indirect.o: T foo()"
  else
    expect_log "Duplicate symbols found in .*/pkg/libstatic.a:"
    expect_log "direct1.pic.o: T foo()"
    expect_log "indirect.pic.o: T foo()"
  fi

  bazel build //pkg:static \
    --features=-symbol_check \
    &> $TEST_log || fail "Expected build to succeed"
}

function test_cc_static_library_duplicate_symbol_mixed_type() {
  mkdir -p pkg
  cat > pkg/BUILD<<'EOF'
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc:cc_static_library.bzl", "cc_static_library")
cc_static_library(
    name = "static",
    deps = [
        ":direct1",
        ":direct2",
    ],
)
cc_library(
    name = "direct1",
    srcs = ["direct1.cc"],
)
cc_library(
    name = "direct2",
    srcs = ["direct2.cc"],
    deps = [":indirect"],
)
cc_library(
    name = "indirect",
    srcs = ["indirect.cc"],
)
EOF
  cat > pkg/direct1.cc<<'EOF'
int foo;
EOF
  cat > pkg/direct2.cc<<'EOF'
int bar = 21;
EOF
  cat > pkg/indirect.cc<<'EOF'
int foo = 21;
EOF

  bazel build //pkg:static \
    &> $TEST_log && fail "Expected build to fail"
  if is_windows; then
    expect_log "direct1.obj"
    expect_log "indirect.obj"
    expect_log " foo"
  elif is_darwin; then
    expect_log "Duplicate symbols found in .*/pkg/libstatic.a:"
    expect_log "direct1.o: S _foo"
    expect_log "indirect.o: D _foo"
  else
    expect_log "Duplicate symbols found in .*/pkg/libstatic.a:"
    expect_log "direct1.pic.o: B foo"
    expect_log "indirect.pic.o: D foo"
  fi

  bazel build //pkg:static \
    --features=-symbol_check \
    &> $TEST_log || fail "Expected build to succeed"
}

run_suite "Failure tests for cc_static_library"
