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
    "ActionTypeInfo",
    "ArgsInfo",
    "ArgsListInfo",
)

visibility("private")

_C_COMPILE_FILE = "tests/rule_based_toolchain/testdata/file1"
_CPP_COMPILE_FILE = "tests/rule_based_toolchain/testdata/file2"
_BOTH_FILE = "tests/rule_based_toolchain/testdata/multiple1"

def _collect_args_lists_test(env, targets):
    args = env.expect.that_target(targets.args_list).provider(ArgsListInfo)
    args.args().contains_exactly([
        targets.c_compile_args.label,
        targets.cpp_compile_args.label,
        targets.all_compile_args.label,
    ])
    args.files().contains_exactly([
        _C_COMPILE_FILE,
        _CPP_COMPILE_FILE,
        _BOTH_FILE,
    ])

    c_compile_action = args.by_action().get(targets.c_compile[ActionTypeInfo])
    cpp_compile_action = args.by_action().get(targets.cpp_compile[ActionTypeInfo])

    c_compile_action.files().contains_exactly([_C_COMPILE_FILE, _BOTH_FILE])
    c_compile_action.args().contains_exactly([
        targets.c_compile_args[ArgsInfo],
        targets.all_compile_args[ArgsInfo],
    ])
    cpp_compile_action.files().contains_exactly([_CPP_COMPILE_FILE, _BOTH_FILE])
    cpp_compile_action.args().contains_exactly([
        targets.cpp_compile_args[ArgsInfo],
        targets.all_compile_args[ArgsInfo],
    ])

TARGETS = [
    ":c_compile_args",
    ":cpp_compile_args",
    ":all_compile_args",
    ":args_list",
    "//tests/rule_based_toolchain/actions:c_compile",
    "//tests/rule_based_toolchain/actions:cpp_compile",
]

TESTS = {
    "collect_args_lists_test": _collect_args_lists_test,
}
