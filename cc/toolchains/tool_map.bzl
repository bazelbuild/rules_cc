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
"""Implementation of cc_tool_map."""

load(
    "//cc/toolchains/impl:collect.bzl",
    "collect_provider",
    "collect_tools",
)
load(
    ":cc_toolchain_info.bzl",
    "ActionTypeSetInfo",
    "ToolConfigInfo",
)

def _cc_tool_map_impl(ctx):
    tools = collect_tools(ctx, ctx.attr.tools)
    action_sets = collect_provider(ctx.attr.actions, ActionTypeSetInfo)

    action_to_tool = {}
    action_to_as = {}
    for i in range(len(action_sets)):
        action_set = action_sets[i]
        tool = tools[i]

        for action in action_set.actions.to_list():
            if action in action_to_as:
                fail("The action %s appears multiple times in your tool_map (as %s and %s)" % (action.label, action_set.label, action_to_as[action].label))
            action_to_as[action] = action_set
            action_to_tool[action] = tool

    return [ToolConfigInfo(label = ctx.label, configs = action_to_tool)]

_cc_tool_map = rule(
    implementation = _cc_tool_map_impl,
    # @unsorted-dict-items
    attrs = {
        "actions": attr.label_list(
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

A tool is usually a binary, but may be a `cc_tool`.

If multiple tools are specified, the first tool that has `with_features` that
satisfy the currently enabled feature set is used.
""",
        ),
    },
    provides = [ToolConfigInfo],
)

def cc_tool_map(name, tools, **kwargs):
    """Configuration for which actions require which tools.

    Args:
        name: (str) The name of the target
        tools: (Dict[Action target, Executable target])
        **kwargs: kwargs to be passed to the underlying rule.
    """
    _cc_tool_map(
        name = name,
        actions = tools.keys(),
        tools = tools.values(),
        **kwargs
    )
