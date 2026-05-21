# Setup runfiles and the test directory and then run the provided test script.

set -euo pipefail

# --- begin runfiles.bash initialization v3 ---
# Copy-pasted from the Bazel Bash runfiles library v3.
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
# shellcheck disable=SC1090
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo>&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v3 ---

# create_scratch_dir_sh_location=rules_bazel_integration_test/tools/create_scratch_dir.sh
# create_scratch_dir_sh="$(rlocation "${create_scratch_dir_sh_location}")" || \
#   (echo >&2 "Failed to locate ${create_scratch_dir_sh_location}" && exit 1)
# 
# scratch_dir="$("${create_scratch_dir_sh}" --workspace "${BIT_WORKSPACE_DIR}")"
# 
# # Have the provided bazel sit on PATH
# echo "$BIT_BAZEL_BINARY"
# BAZEL_BIN_DIR="$(dirname $BIT_BAZEL_BINARY)"
# export PATH="$BAZEL_BIN_DIR:$PATH"
# ln -s "$BIT_BAZEL_BINARY" "$BAZEL_BIN_DIR/bazel"


source "$(rlocation rules_cc/tests/integration/platform_utils.sh)"

bazel_binary="$(rlocation "$BAZEL_BINARY")"

scratch_dir="$TEST_TMPDIR/workspace"
mkdir -p $scratch_dir
bazel_bin_dir="$TEST_TMPDIR/bazel"
mkdir -p $bazel_bin_dir

if is_windows; then
  scratch_dir="$(cygpath -u $scratch_dir)"
  bazel_bin_dir="$(cygpath -u $bazel_bin_dir)"
fi

cp "$bazel_binary" "$bazel_bin_dir/bazel"

ls -l "$bazel_bin_dir"

export PATH="$bazel_bin_dir:$PATH"

export TEST_log="$scratch_dir/test.log"

workspace="$(rlocation "rules_cc/$WORKSPACE_DIR")"

cp -r "$workspace"/* "$scratch_dir/"

test_runner_path="$(rlocation "rules_cc/${TEST_RUNNER}")" || (echo >&2 "FAILED TO LOAD RUNNER" && exit 1)
test_runner_cmd=( "${test_runner_path}" )

# Change into scratch workspace
cd "${scratch_dir}"
echo "$WORKSPACE_PATH"
echo "$(rlocation "$WORKSPACE_PATH")"
cd "$WORKSPACE_PATH"

echo "WHICH BAZEL"
which bazel
bazel version

echo "$test_runner_cmd"
"${test_runner_cmd[@]}"
