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
    "args_wrapper_macro",
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

    if not ctx.attr.args and not ctx.attr.nested and not ctx.attr.env:
        fail("cc_args requires at least one of args, nested, and env")

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
        files = collect_files(ctx.attr.data)

    requires = collect_provider(ctx.attr.requires_any_of, FeatureConstraintInfo)

    args = ArgsInfo(
        label = ctx.label,
        actions = actions,
        requires_any_of = tuple(requires),
        nested = nested,
        env = ctx.attr.env,
        files = files,
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

cc_args = lambda **kwargs: args_wrapper_macro(rule = _cc_args, **kwargs)
