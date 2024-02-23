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

load(
    "//cc/toolchains/impl:collect.bzl",
    "collect_action_types",
    "collect_files",
    "collect_provider",
)
load(
    ":cc_toolchain_info.bzl",
    "ActionTypeSetInfo",
    "AddArgsInfo",
    "ArgsInfo",
    "ArgsListInfo",
    "FeatureConstraintInfo",
)

visibility("public")

def _cc_args_impl(ctx):
    add_args = [AddArgsInfo(
        label = ctx.label,
        args = tuple(ctx.attr.args),
        files = depset([]),
    )]

    actions = collect_action_types(ctx.attr.actions)
    files = collect_files(ctx.attr.additional_files)
    requires = collect_provider(ctx.attr.requires_any_of, FeatureConstraintInfo)

    args = ArgsInfo(
        label = ctx.label,
        actions = actions,
        requires_any_of = tuple(requires),
        files = files,
        args = add_args,
        env = ctx.attr.env,
    )
    return [
        args,
        ArgsListInfo(
            label = ctx.label,
            args = tuple([args]),
            files = files,
            by_action = tuple([
                struct(action = action, args = [args], files = files)
                for action in actions.to_list()
            ]),
        ),
    ]

cc_args = rule(
    implementation = _cc_args_impl,
    attrs = {
        "actions": attr.label_list(
            providers = [ActionTypeSetInfo],
            mandatory = True,
            doc = """A list of action types that this flag set applies to.

See @rules_cc//cc/toolchains/actions:all for valid options.
""",
        ),
        "additional_files": attr.label_list(
            allow_files = True,
            doc = """Files required to add this argument to the command-line.

For example, a flag that sets the header directory might add the headers in that
directory as additional files.
""",
        ),
        "args": attr.string_list(
            doc = """Arguments that should be added to the command-line.

These are evaluated in order, with earlier args appearing earlier in the
invocation of the underlying tool.
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
    },
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
