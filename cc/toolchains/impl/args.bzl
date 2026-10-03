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
"""Shared implementation and attributes for cc_args and cc_sysroot."""

load("@bazel_skylib//rules/directory:providers.bzl", "DirectoryInfo")
load("//cc/private:paths.bzl", "is_path_absolute")
load(
    "//cc/toolchains:cc_toolchain_info.bzl",
    "ActionTypeSetInfo",
    "ArgsInfo",
    "ArgsListInfo",
    "BuiltinVariablesInfo",
    "EnvInfo",
    "FeatureConstraintInfo",
    "VariableInfo",
)
load(":args_utils.bzl", "validate_env_variables", "validate_nested_args")
load(
    ":collect.bzl",
    "collect_action_types",
    "collect_files",
    "collect_provider",
)
load(
    ":nested_args.bzl",
    "NESTED_ARGS_ATTRS",
    "format_dict_values",
    "nested_args_provider_from_ctx",
)

visibility([
    "//cc/toolchains",
    "//cc/toolchains/args",
])

def cc_args_impl(ctx):
    """Builds argument providers for cc_args and cc_sysroot.

    Args:
        ctx: The rule context.

    Returns:
        ArgsInfo and ArgsListInfo providers.
    """
    actions = collect_action_types(ctx.attr.actions)
    actions_list = actions.to_list()
    variables = ctx.attr._variables[BuiltinVariablesInfo].variables

    format_targets = {k: v for v, k in ctx.attr.format.items()}
    formatted_env, used_format_vars = format_dict_values(
        env = ctx.attr.env,
        must_use = [],  # checking for unused variables in done when formatting `args`.
        format = {k: struct(__raw_string = v) for k, v in ctx.var.items()} | format_targets,
    )
    used_env_variables = [
        var
        for var in used_format_vars
        if var in format_targets and VariableInfo in format_targets[var]
    ]

    # Ignore file / directory replacements for validation
    # Filter out variables from ctx.var which don't have to be used
    used_format_vars = [
        v
        for v in used_format_vars
        if v in format_targets and VariableInfo in format_targets[v]
    ]

    for path in ctx.attr.allowlist_absolute_include_directories:
        if not is_path_absolute(path):
            fail("`{}` is not an absolute paths".format(path))

    nested = None
    if ctx.attr.args or ctx.attr.nested:
        # Forward the format variables used by the env formatting so they don't trigger
        # errors if they go unused during the argument formatting.
        nested = nested_args_provider_from_ctx(ctx, used_format_vars)
        validate_nested_args(
            variables = variables,
            nested_args = nested,
            actions = actions_list,
            label = ctx.label,
        )
        files = nested.files
    else:
        files = collect_files(ctx.attr.data)

    requires = collect_provider(ctx.attr.requires_any_of, FeatureConstraintInfo)

    env = EnvInfo(
        label = ctx.label,
        entries = formatted_env,
        requires_not_none = ctx.attr.requires_not_none[VariableInfo].name if ctx.attr.requires_not_none else None,
    )
    validate_env_variables(
        actions = actions_list,
        env = env,
        variables = variables,
        used_format_vars = used_env_variables,
    )

    args = ArgsInfo(
        label = ctx.label,
        actions = actions,
        requires_any_of = tuple(requires),
        nested = nested,
        env = env,
        files = files,
        allowlist_include_directories = depset(
            direct = [d[DirectoryInfo] for d in ctx.attr.allowlist_include_directories],
        ),
        allowlist_absolute_include_directories = depset(
            direct = ctx.attr.allowlist_absolute_include_directories,
        ),
    )
    args_tuple = (args,)

    return [
        args,
        ArgsListInfo(
            label = ctx.label,
            args = args_tuple,
            files = files,
            by_action = tuple([
                struct(action = action, args = args_tuple, files = files)
                for action in actions_list
            ]),
            allowlist_include_directories = args.allowlist_include_directories,
            allowlist_absolute_include_directories = args.allowlist_absolute_include_directories,
        ),
    ]

CC_ARGS_ATTRS = {
    "actions": attr.label_list(
        providers = [ActionTypeSetInfo],
        mandatory = True,
        doc = """See documentation for cc_args macro wrapper.""",
    ),
    "allowlist_absolute_include_directories": attr.string_list(
        doc = """See documentation for cc_args macro wrapper.""",
    ),
    "allowlist_include_directories": attr.label_list(
        providers = [DirectoryInfo],
        doc = """See documentation for cc_args macro wrapper.""",
    ),
    "env": attr.string_dict(
        doc = """See documentation for cc_args macro wrapper.""",
    ),
    "requires_any_of": attr.label_list(
        providers = [FeatureConstraintInfo],
        doc = """See documentation for cc_args macro wrapper.""",
    ),
    "_variables": attr.label(
        default = "//cc/toolchains/variables:variables",
    ),
} | NESTED_ARGS_ATTRS
