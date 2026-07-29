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

"""Tests for action_command_line_test."""

load("//tests/cc/testutil:action_command_line_test.bzl", "make_action_command_line_test_rule")
load("//tests/cc/testutil/toolchains:features.bzl", "FEATURE_NAMES")

visibility("private")

_MOCK_TOOLCHAINS = [
    "//tests/cc/testutil/toolchains:cc-toolchain-k8-compiler",
    "//tests/cc/testutil/toolchains:cc-toolchain-macos-compiler",
]

_WITH_FEATURES = str(Label("//tests/cc/testutil/toolchains:with_features"))

mock_toolchain_action_command_line_test = make_action_command_line_test_rule(
    config_settings = {
        "//command_line_option:collect_code_coverage": "false",
        "//command_line_option:compilation_mode": "fastbuild",
        "//command_line_option:extra_toolchains": ",".join(_MOCK_TOOLCHAINS),
        "//command_line_option:features": [FEATURE_NAMES.simple_compile_feature],
        _WITH_FEATURES: [FEATURE_NAMES.simple_compile_feature],
    },
)
