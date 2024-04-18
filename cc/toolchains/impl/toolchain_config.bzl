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
load(":legacy_converter.bzl", "convert_toolchain")
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
        fail("Rule based toolchains are experimental. To use it, please add --@rules_cc//cc/toolchains:experimental_enable_rule_based_toolchains to your bazelrc")

    toolchain_config = toolchain_config_info(
        label = ctx.label,
        features = ctx.attr.toolchain_features + [ctx.attr._builtin_features],
        action_type_configs = ctx.attr.action_type_configs,
        args = ctx.attr.args,
    )

    legacy = convert_toolchain(toolchain_config)

    return [
        toolchain_config,
        cc_common.create_cc_toolchain_config_info(
            ctx = ctx,
            action_configs = legacy.action_configs,
            features = legacy.features,
            cxx_builtin_include_directories = ctx.attr.cxx_builtin_include_directories,
            # toolchain_identifier is deprecated, but setting it to None results
            # in an error that it expected a string, and for safety's sake, I'd
            # prefer to provide something unique.
            toolchain_identifier = str(ctx.label),
            target_system_name = ctx.attr.target_system_name,
            target_cpu = ctx.attr.target_cpu,
            target_libc = ctx.attr.target_libc,
            compiler = ctx.attr.compiler,
            abi_version = ctx.attr.abi_version,
            abi_libc_version = ctx.attr.abi_libc_version,
            builtin_sysroot = ctx.attr.sysroot or None,
        ),
        # This allows us to support all_files.
        # If all_files was simply an alias to
        # ///cc/toolchains/actions:all_actions,
        # then if a toolchain introduced a new type of action, it wouldn't get
        # put in all_files.
        DefaultInfo(files = depset(transitive = toolchain_config.files.values())),
    ]

cc_toolchain_config = rule(
    implementation = _cc_toolchain_config_impl,
    # @unsorted-dict-items
    attrs = {
        # Attributes new to this rule.
        "action_type_configs": attr.label_list(providers = [ActionTypeConfigSetInfo]),
        "args": attr.label_list(providers = [ArgsListInfo]),
        "toolchain_features": attr.label_list(providers = [FeatureSetInfo]),
        "skip_experimental_flag_validation_for_test": attr.bool(default = False),
        "_builtin_features": attr.label(default = "//cc/toolchains/features:all_builtin_features"),
        "_enabled": attr.label(default = "//cc/toolchains:experimental_enable_rule_based_toolchains"),

        # Attributes from create_cc_toolchain_config_info.
        # artifact_name_patterns is currently unused. Consider adding it later.
        # TODO: Consider making this into a label_list that takes a
        #  cc_directory_marker rule as input.
        "cxx_builtin_include_directories": attr.string_list(),
        "target_system_name": attr.string(mandatory = True),
        "target_cpu": attr.string(mandatory = True),
        "target_libc": attr.string(mandatory = True),
        "compiler": attr.string(mandatory = True),
        "abi_version": attr.string(),
        "abi_libc_version": attr.string(),
        # tool_paths currently unused.
        # TODO: Consider making this into a label that takes a
        #  cc_directory_marker rule as an input.
        "sysroot": attr.string(),
    },
    provides = [ToolchainConfigInfo],
)
