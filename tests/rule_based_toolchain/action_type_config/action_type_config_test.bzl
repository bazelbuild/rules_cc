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
"""Tests for the action_type_config rule."""

load(
    "//cc/toolchains:cc_toolchain_info.bzl",
    "ActionTypeConfigSetInfo",
    "ActionTypeInfo",
)
load("//cc/toolchains/impl:collect.bzl", _collect_action_type_configs = "collect_action_type_config_sets")
load("//tests/rule_based_toolchain:subjects.bzl", "result_fn_wrapper", "subjects")

visibility("private")

_TOOL_FILES = [
    "tests/rule_based_toolchain/testdata/bin",
    "tests/rule_based_toolchain/testdata/bin_wrapper",
    "tests/rule_based_toolchain/testdata/bin_wrapper.sh",
]
_ADDITIONAL_FILES = [
    "tests/rule_based_toolchain/testdata/multiple2",
]
_C_COMPILE_FILES = [
    "tests/rule_based_toolchain/testdata/file1",
    "tests/rule_based_toolchain/testdata/multiple1",
]
_CPP_COMPILE_FILES = [
    "tests/rule_based_toolchain/testdata/file2",
    "tests/rule_based_toolchain/testdata/multiple1",
]

collect_action_type_configs = result_fn_wrapper(_collect_action_type_configs)

def _files_taken_test(env, targets):
    configs = env.expect.that_target(targets.file_map).provider(ActionTypeConfigSetInfo).configs()
    c_compile = configs.get(targets.c_compile[ActionTypeInfo])
    c_compile.files().contains_exactly(
        _C_COMPILE_FILES + _TOOL_FILES + _ADDITIONAL_FILES,
    )
    c_compile.args().contains_exactly([
        targets.c_compile_args.label,
        targets.all_compile_args.label,
    ])

    cpp_compile = configs.get(targets.cpp_compile[ActionTypeInfo])
    cpp_compile.files().contains_exactly(
        _CPP_COMPILE_FILES + _TOOL_FILES + _ADDITIONAL_FILES,
    )
    cpp_compile.args().contains_exactly([
        targets.cpp_compile_args.label,
        targets.all_compile_args.label,
    ])

def _merge_distinct_configs_succeeds_test(env, targets):
    configs = env.expect.that_value(
        collect_action_type_configs(
            targets = [targets.c_compile_config, targets.cpp_compile_config],
            label = env.ctx.label,
        ),
        factory = subjects.result(subjects.ActionTypeConfigSetInfo),
    ).ok().configs()
    configs.get(targets.c_compile[ActionTypeInfo]).label().equals(
        targets.c_compile_config.label,
    )
    configs.get(targets.cpp_compile[ActionTypeInfo]).label().equals(
        targets.cpp_compile_config.label,
    )

def _merge_overlapping_configs_fails_test(env, targets):
    err = env.expect.that_value(
        collect_action_type_configs(
            targets = [targets.file_map, targets.c_compile_config],
            label = env.ctx.label,
        ),
        factory = subjects.result(subjects.ActionTypeConfigSetInfo),
    ).err()
    err.contains("//tests/rule_based_toolchain/actions:c_compile is configured by both")
    err.contains("//tests/rule_based_toolchain/action_type_config:c_compile_config")
    err.contains("//tests/rule_based_toolchain/action_type_config:file_map")

TARGETS = [
    ":file_map",
    ":c_compile_config",
    ":cpp_compile_config",
    "//tests/rule_based_toolchain/actions:c_compile",
    "//tests/rule_based_toolchain/actions:cpp_compile",
    "//tests/rule_based_toolchain/args_list:c_compile_args",
    "//tests/rule_based_toolchain/args_list:cpp_compile_args",
    "//tests/rule_based_toolchain/args_list:all_compile_args",
    "//tests/rule_based_toolchain/args_list:args_list",
]

TESTS = {
    "files_taken_test": _files_taken_test,
    "merge_distinct_configs_succeeds_test": _merge_distinct_configs_succeeds_test,
    "merge_overlapping_configs_fails_test": _merge_overlapping_configs_fails_test,
}
