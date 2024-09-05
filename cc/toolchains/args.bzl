# Copyright 2024 The Bazel Authors. All rights reserved.
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
"""All providers for rule-based bazel toolchain config."""

load("@bazel_skylib//rules/directory:providers.bzl", "DirectoryInfo")
load("//cc/toolchains/impl:args_utils.bzl", "validate_nested_args")
load(
    "//cc/toolchains/impl:collect.bzl",
    "collect_action_types",
    "collect_files",
    "collect_provider",
)
load(
    "//cc/toolchains/impl:nested_args.bzl",
    "NESTED_ARGS_ATTRS",
    "nested_args_provider_from_ctx",
)
load(
    ":cc_toolchain_info.bzl",
    "ActionTypeSetInfo",
    "ArgsInfo",
    "ArgsListInfo",
    "BuiltinVariablesInfo",
    "FeatureConstraintInfo",
)

visibility("public")

def _cc_args_impl(ctx):
    actions = collect_action_types(ctx.attr.actions)

    nested = None
    if ctx.attr.args or ctx.attr.nested:
        nested = nested_args_provider_from_ctx(ctx)
        validate_nested_args(
            variables = ctx.attr._variables[BuiltinVariablesInfo].variables,
            nested_args = nested,
            actions = actions.to_list(),
            label = ctx.label,
        )
        files = nested.files
    else:
        files = collect_files(ctx.attr.data + ctx.attr.allowlist_include_directories)

    requires = collect_provider(ctx.attr.requires_any_of, FeatureConstraintInfo)

    args = ArgsInfo(
        label = ctx.label,
        actions = actions,
        requires_any_of = tuple(requires),
        nested = nested,
        env = ctx.attr.env,
        files = files,
        allowlist_include_directories = depset(
            direct = [d[DirectoryInfo] for d in ctx.attr.allowlist_include_directories],
        ),
    )
    return [
        args,
        ArgsListInfo(
            label = ctx.label,
            args = tuple([args]),
            files = files,
            by_action = tuple([
                struct(action = action, args = tuple([args]), files = files)
                for action in actions.to_list()
            ]),
            allowlist_include_directories = args.allowlist_include_directories,
        ),
    ]

_cc_args = rule(
    implementation = _cc_args_impl,
    attrs = {
        "actions": attr.label_list(
            providers = [ActionTypeSetInfo],
            mandatory = True,
            doc = """A list of action types that this flag set applies to.

See @rules_cc//cc/toolchains/actions:all for valid options.
""",
        ),
        "env": attr.string_dict(
            doc = "Environment variables to be added to the command-line.",
        ),
        "allowlist_include_directories": attr.label_list(
            providers = [DirectoryInfo],
            doc = """Include paths implied by using this rule.

Some flags (e.g. --sysroot) imply certain include paths are available despite
not explicitly specifying a normal include path flag (`-I`, `-isystem`, etc.).
Bazel checks that all included headers are properly provided by a dependency or
allowlisted through this mechanism.
""",
        ),
        "requires_any_of": attr.label_list(
            providers = [FeatureConstraintInfo],
            doc = """This will be enabled when any of the constraints are met.

If omitted, this flag set will be enabled unconditionally.
""",
        ),
        "_variables": attr.label(
            default = "//cc/toolchains/variables:variables",
        ),
    } | NESTED_ARGS_ATTRS,
    provides = [ArgsInfo],
    doc = """Declares a list of arguments bound to a set of actions.

Roughly equivalent to ctx.actions.args()

Examples:
    cc_args(
        name = "warnings_as_errors",
        args = ["-Werror"],
    )
""",
)

def cc_args(name, format = {}, **kwargs):
    return _cc_args(
        name = name,
        format = {k: v for v, k in format.items()},
        **kwargs
    )
