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

"""Integration test rule for rules_cc."""

load("@rules_shell//shell:sh_test.bzl", "sh_test")

def rules_cc_integration_test(
        name,
        test_script,
        data = [],
        env = {},
        **kwargs):
    """Integration test for rules_cc.

    Args:
        name: The name of the test.
        test_script: The shell script for the test.
        data: (optional) Additional data dependencies required for the test.
        env: (optional) Additional environment variables to pass to the test.
        **kwargs: Additional arguments to pass to the test target.
    """

    bazel_bin = "@local_bazel//:bazel"

    test_env = {
        "TEST_RUNNER": "$(rlocationpath %s)" % test_script,
        "BAZEL_BINARY": "$(rlocationpath %s)" % bazel_bin,
    }
    test_env.update(env)

    sh_test(
        name = name,
        srcs = [
            "//tests/integration:test_launcher.sh",
        ],
        data = [
            bazel_bin,
            test_script,
            "//tests:test_utils_sh",
            "//tests:unittest_bash",
            "//cc:srcs",
            "//:srcs",
            "@rules_shell//shell/runfiles",
        ] + data,
        env = test_env,
        **kwargs
    )
