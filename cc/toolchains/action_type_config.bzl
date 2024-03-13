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
"""Implementation of cc_action_type_config."""

load("//cc/toolchains/impl:args_utils.bzl", "get_action_type")
load(
    "//cc/toolchains/impl:collect.bzl",
    "collect_action_types",
    "collect_args_lists",
    "collect_features",
    "collect_files",
    "collect_tools",
)
load(
    ":cc_toolchain_info.bzl",
    "ActionTypeConfigInfo",
    "ActionTypeConfigSetInfo",
    "ActionTypeSetInfo",
    "ArgsListInfo",
    "FeatureSetInfo",
)

def _cc_action_type_config_impl(ctx):
    if not ctx.attr.action_types:
        fail("At least one action type is required for cc_action_type_config")
    if not ctx.attr.tools:
        fail("At least one tool is required for cc_action_type_config")

    tools = tuple(collect_tools(ctx, ctx.attr.tools))
    implies = collect_features(ctx.attr.implies)
    args_list = collect_args_lists(ctx.attr.args, ctx.label)
    files = collect_files(ctx.attr.data)

    configs = {}
    for action_type in collect_action_types(ctx.attr.action_types).to_list():
        for_action = get_action_type(args_list, action_type)
        configs[action_type] = ActionTypeConfigInfo(
            label = ctx.label,
            action_type = action_type,
            tools = tools,
            args = for_action.args,
            implies = implies,
            files = ctx.runfiles(
                transitive_files = depset(transitive = [files, for_action.files]),
            ).merge_all([tool.runfiles for tool in tools]),
        )

    return [ActionTypeConfigSetInfo(label = ctx.label, configs = configs)]

cc_action_type_config = rule(
    implementation = _cc_action_type_config_impl,
    # @unsorted-dict-items
    attrs = {
        "action_types": attr.label_list(
            providers = [ActionTypeSetInfo],
            mandatory = True,
            doc = """A list of action names to apply this action to.

See @toolchain//actions:all for valid options.
""",
        ),
        "tools": attr.label_list(
            mandatory = True,
            cfg = "exec",
            allow_files = True,
            doc = """The tool to use for the specified actions.

A tool can be a `cc_tool`, or a binary.

If multiple tools are specified, the first tool that has `with_features` that
satisfy the currently enabled feature set is used.
""",
        ),
        "args": attr.label_list(
            providers = [ArgsListInfo],
            doc = """Labels that point to `cc_arg`s / `cc_arg_list`s that are
unconditionally bound to the specified actions.
""",
        ),
        "implies": attr.label_list(
            providers = [FeatureSetInfo],
            doc = "Features that should be enabled when this action is used.",
        ),
        "data": attr.label_list(
            allow_files = True,
            doc = """Files required for this action type.

For example, the c-compile action type might add the C standard library header
files from the sysroot.
""",
        ),
    },
    provides = [ActionTypeConfigSetInfo],
    doc = """Declares the configuration and selection of `cc_tool` rules.

Action configs are bound to a toolchain through `action_configs`, and are the
driving mechanism for controlling toolchain tool invocation/behavior.

Action configs define three key things:

* Which tools to invoke for a given type of action.
* Tool features and compatibility.
* `cc_args`s that are unconditionally bound to a tool invocation.

Examples:

    cc_action_config(
        name = "ar",
        action_types = ["@toolchain//actions:all_ar_actions"],
        implies = [
            "@toolchain//features/legacy:archiver_flags",
            "@toolchain//features/legacy:linker_param_file",
        ],
        tools = [":ar_tool"],
    )

    cc_action_config(
        name = "clang",
        action_types = [
            "@toolchain//actions:all_asm_actions",
            "@toolchain//actions:all_c_compiler_actions",
        ],
        tools = [":clang_tool"],
    )
""",
)
