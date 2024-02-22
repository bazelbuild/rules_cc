# Copyright 2024 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Tests for the cc_args rule."""

load(
    "//cc/toolchains:cc_toolchain_info.bzl",
    "ArgsInfo",
)

visibility("private")

def _test_simple_args_impl(env, targets):
    simple = env.expect.that_target(targets.simple).provider(ArgsInfo)
    simple.actions().contains_exactly([
        targets.c_compile.label,
        targets.cpp_compile.label,
    ])
    simple.args().contains_exactly([targets.simple.label])
    simple.env().contains_exactly({"BAR": "bar"})
    simple.files().contains_exactly([
        "tests/rule_based_toolchain/testdata/file1",
        "tests/rule_based_toolchain/testdata/multiple1",
        "tests/rule_based_toolchain/testdata/multiple2",
    ])

TARGETS = [
    ":simple",
    "//tests/rule_based_toolchain/actions:c_compile",
    "//tests/rule_based_toolchain/actions:cpp_compile",
]

TESTS = {
    "simple_test": _test_simple_args_impl,
}
