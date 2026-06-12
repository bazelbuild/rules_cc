# Copyright 2026 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Setup runfiles and the test directory and then run the provided test script.

[ -z "$TEST_SRCDIR" ] && { echo "TEST_SRCDIR not set!" >&2; exit 1; }

export TEST_log=$TEST_TMPDIR/log

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

source "$(rlocation rules_cc/tests/test_utils.sh)"

# Set environment vars for Windows
if is_windows; then
  export MSYS_NO_PATHCONV=1
fi

# Put bazel on PATH
bazel_binary="$(rlocation "$BAZEL_BINARY")"
bazel_bin_dir="$TEST_TMPDIR/bazel"
if is_windows; then
    bazel_bin_dir="$(cygpath -u "$bazel_bin_dir")"
fi
mkdir -p "$bazel_bin_dir"
cp "$bazel_binary" "$bazel_bin_dir/bazel"
export PATH="$bazel_bin_dir:$PATH"

rules_cc_module="$(rlocation rules_cc/MODULE.bazel)"
rules_cc_dir="$(dirname "$rules_cc_module")"

# Create a scratch workspace
scratch_workspace="$TEST_TMPDIR/scratch"
mkdir -p "$scratch_workspace"
cd "$scratch_workspace"

# Make rules_cc available
cat > MODULE.bazel << EOF
module(name = "test_module")

bazel_dep(name = "apple_support", version = "2.6.1")
bazel_dep(name = "rules_cc", version = "0.0.0")
local_path_override(
    module_name = "rules_cc",
    path = "$rules_cc_dir"
)

cc_configure = use_extension("@rules_cc//cc:extensions.bzl", "cc_configure_extension")
use_repo(cc_configure, "local_config_cc", "local_config_cc_toolchains")
register_toolchains("@local_config_cc_toolchains//:all")
EOF

test_runner_path="$(rlocation "$TEST_RUNNER")" || (echo >&2 "FAILED TO LOAD TEST RUNNER" && exit 1)
test_runner_cmd=( "${test_runner_path}" )

echo "$test_runner_cmd"
"${test_runner_cmd[@]}"
