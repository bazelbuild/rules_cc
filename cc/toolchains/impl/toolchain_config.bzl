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
"""Implementation of the cc_toolchain rule."""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load(
    "//cc/toolchains:cc_toolchain_info.bzl",
    "ActionTypeConfigSetInfo",
    "ActionTypeSetInfo",
    "ArgsListInfo",
    "FeatureSetInfo",
    "ToolchainConfigInfo",
)
load(":collect.bzl", "collect_action_types")
load(":toolchain_config_info.bzl", "toolchain_config_info")

visibility([
    "//cc/toolchains/...",
    "//tests/rule_based_toolchain/...",
])

def _cc_legacy_file_group_impl(ctx):
    files = ctx.attr.config[ToolchainConfigInfo].files

    return [DefaultInfo(files = depset(transitive = [
        files[action]
        for action in collect_action_types(ctx.attr.actions).to_list()
        if action in files
    ]))]

cc_legacy_file_group = rule(
    implementation = _cc_legacy_file_group_impl,
    attrs = {
        "actions": attr.label_list(providers = [ActionTypeSetInfo], mandatory = True),
        "config": attr.label(providers = [ToolchainConfigInfo], mandatory = True),
    },
)

def _cc_toolchain_config_impl(ctx):
    if ctx.attr.features:
        fail("Features is a reserved attribute in bazel. Did you mean 'toolchain_features'")

    if not ctx.attr._enabled[BuildSettingInfo].value and not ctx.attr.skip_experimental_flag_validation_for_test:
        fail("Rule based toolchains are experimental. To use it, please add --//cc/toolchains:experimental_enable_rule_based_toolchains to your bazelrc")

    toolchain_config = toolchain_config_info(
        label = ctx.label,
        features = ctx.attr.toolchain_features + [ctx.attr._builtin_features],
        action_type_configs = ctx.attr.action_type_configs,
        args = ctx.attr.args,
    )

    return [
        # TODO: Transform toolchain_config into legacy cc_toolchain_config_info
        toolchain_config,
    ]

cc_toolchain_config = rule(
    implementation = _cc_toolchain_config_impl,
    # @unsorted-dict-items
    attrs = {
        "action_type_configs": attr.label_list(providers = [ActionTypeConfigSetInfo]),
        "args": attr.label_list(providers = [ArgsListInfo]),
        "toolchain_features": attr.label_list(providers = [FeatureSetInfo]),
        "skip_experimental_flag_validation_for_test": attr.bool(default = False),
        "_builtin_features": attr.label(default = "//cc/toolchains/features:all_builtin_features"),
        "_enabled": attr.label(default = "//cc/toolchains:experimental_enable_rule_based_toolchains"),
    },
    provides = [ToolchainConfigInfo],
)
