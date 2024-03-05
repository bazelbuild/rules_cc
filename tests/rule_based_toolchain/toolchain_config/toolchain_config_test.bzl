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

load("//cc/toolchains:cc_toolchain_info.bzl", "ActionTypeInfo")
load("//cc/toolchains/impl:toolchain_config_info.bzl", _toolchain_config_info = "toolchain_config_info")
load("//tests/rule_based_toolchain:subjects.bzl", "result_fn_wrapper", "subjects")

visibility("private")

toolchain_config_info = result_fn_wrapper(_toolchain_config_info)

def _expect_that_toolchain(env, expr = None, **kwargs):
    return env.expect.that_value(
        value = toolchain_config_info(label = Label("//:toolchain"), **kwargs),
        expr = expr,
        factory = subjects.result(subjects.ToolchainConfigInfo),
    )

def _empty_toolchain_valid_test(env, _targets):
    _expect_that_toolchain(env).ok()

def _duplicate_feature_names_invalid_test(env, targets):
    _expect_that_toolchain(
        env,
        features = [targets.simple_feature, targets.same_feature_name],
        expr = "duplicate_feature_name",
    ).err().contains_all_of([
        "The feature name simple_feature was defined by",
        targets.same_feature_name.label,
        targets.simple_feature.label,
    ])

    # Overriding a feature gives it the same name. Ensure this isn't blocked.
    _expect_that_toolchain(
        env,
        features = [targets.builtin_feature, targets.overrides_feature],
        expr = "override_feature",
    ).ok()

def _duplicate_action_type_invalid_test(env, targets):
    _expect_that_toolchain(
        env,
        features = [targets.simple_feature],
        action_type_configs = [targets.compile_config, targets.c_compile_config],
    ).err().contains_all_of([
        "The action type %s is configured by" % targets.c_compile.label,
        targets.compile_config.label,
        targets.c_compile_config.label,
    ])

def _action_config_implies_missing_feature_invalid_test(env, targets):
    _expect_that_toolchain(
        env,
        features = [targets.simple_feature],
        action_type_configs = [targets.c_compile_config],
        expr = "action_type_config_with_implies",
    ).ok()

    _expect_that_toolchain(
        env,
        features = [],
        action_type_configs = [targets.c_compile_config],
        expr = "action_type_config_missing_implies",
    ).err().contains(
        "%s implies the feature %s" % (targets.c_compile_config.label, targets.simple_feature.label),
    )

def _feature_config_implies_missing_feature_invalid_test(env, targets):
    _expect_that_toolchain(
        env,
        expr = "feature_with_implies",
        features = [targets.simple_feature, targets.implies_simple_feature],
    ).ok()

    _expect_that_toolchain(
        env,
        features = [targets.implies_simple_feature],
        expr = "feature_missing_implies",
    ).err().contains(
        "%s implies the feature %s" % (targets.implies_simple_feature.label, targets.simple_feature.label),
    )

def _feature_missing_requirements_invalid_test(env, targets):
    _expect_that_toolchain(
        env,
        features = [targets.requires_any_simple_feature, targets.simple_feature],
        expr = "requires_any_simple_has_simple",
    ).ok()
    _expect_that_toolchain(
        env,
        features = [targets.requires_any_simple_feature, targets.simple_feature2],
        expr = "requires_any_simple_has_simple2",
    ).ok()
    _expect_that_toolchain(
        env,
        features = [targets.requires_any_simple_feature],
        expr = "requires_any_simple_has_none",
    ).err().contains(
        "It is impossible to enable %s" % targets.requires_any_simple_feature.label,
    )

    _expect_that_toolchain(
        env,
        features = [targets.requires_all_simple_feature, targets.simple_feature, targets.simple_feature2],
        expr = "requires_all_simple_has_both",
    ).ok()
    _expect_that_toolchain(
        env,
        features = [targets.requires_all_simple_feature, targets.simple_feature],
        expr = "requires_all_simple_has_simple",
    ).err().contains(
        "It is impossible to enable %s" % targets.requires_all_simple_feature.label,
    )
    _expect_that_toolchain(
        env,
        features = [targets.requires_all_simple_feature, targets.simple_feature2],
        expr = "requires_all_simple_has_simple2",
    ).err().contains(
        "It is impossible to enable %s" % targets.requires_all_simple_feature.label,
    )

def _args_missing_requirements_invalid_test(env, targets):
    _expect_that_toolchain(
        env,
        args = [targets.requires_all_simple_args],
        features = [targets.simple_feature, targets.simple_feature2],
        expr = "has_both",
    ).ok()
    _expect_that_toolchain(
        env,
        args = [targets.requires_all_simple_args],
        features = [targets.simple_feature],
        expr = "has_only_one",
    ).err().contains(
        "It is impossible to enable %s" % targets.requires_all_simple_args.label,
    )

def _tool_missing_requirements_invalid_test(env, targets):
    _expect_that_toolchain(
        env,
        action_type_configs = [targets.requires_all_simple_action_type_config],
        features = [targets.simple_feature, targets.simple_feature2],
        expr = "has_both",
    ).ok()
    _expect_that_toolchain(
        env,
        action_type_configs = [targets.requires_all_simple_action_type_config],
        features = [targets.simple_feature],
        expr = "has_only_one",
    ).err().contains(
        "It is impossible to enable %s" % targets.requires_all_simple_tool.label,
    )

def _toolchain_collects_files_test(env, targets):
    tc = _expect_that_toolchain(
        env,
        args = [targets.c_compile_args],
        action_type_configs = [targets.compile_config],
        features = [targets.compile_feature],
    ).ok()
    tc.files().get(targets.c_compile[ActionTypeInfo]).contains_exactly([
        # From :compile_config's tool
        "tests/rule_based_toolchain/testdata/bin",
        # From :c_compile_args
        "tests/rule_based_toolchain/testdata/file1",
        # From :compile_feature's args
        "tests/rule_based_toolchain/testdata/file2",
    ])
    tc.files().get(targets.cpp_compile[ActionTypeInfo]).contains_exactly([
        # From :compile_config's tool
        "tests/rule_based_toolchain/testdata/bin",
        # From :compile_feature's args
        "tests/rule_based_toolchain/testdata/file2",
    ])

TARGETS = [
    "//tests/rule_based_toolchain/actions:c_compile",
    "//tests/rule_based_toolchain/actions:cpp_compile",
    ":builtin_feature",
    ":compile_config",
    ":compile_feature",
    ":c_compile_args",
    ":c_compile_config",
    ":implies_simple_feature",
    ":overrides_feature",
    ":requires_any_simple_feature",
    ":requires_all_simple_feature",
    ":requires_all_simple_args",
    ":requires_all_simple_action_type_config",
    ":requires_all_simple_tool",
    ":simple_feature",
    ":simple_feature2",
    ":same_feature_name",
]

# @unsorted-dict-items
TESTS = {
    "empty_toolchain_valid_test": _empty_toolchain_valid_test,
    "duplicate_feature_names_fail_validation_test": _duplicate_feature_names_invalid_test,
    "duplicate_action_type_invalid_test": _duplicate_action_type_invalid_test,
    "action_config_implies_missing_feature_invalid_test": _action_config_implies_missing_feature_invalid_test,
    "feature_config_implies_missing_feature_invalid_test": _feature_config_implies_missing_feature_invalid_test,
    "feature_missing_requirements_invalid_test": _feature_missing_requirements_invalid_test,
    "args_missing_requirements_invalid_test": _args_missing_requirements_invalid_test,
    "tool_missing_requirements_invalid_test": _tool_missing_requirements_invalid_test,
    "toolchain_collects_files_test": _toolchain_collects_files_test,
}
