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
"""Helper functions to allow us to collect data from attr.label_list."""

load(
    "//cc/toolchains:cc_toolchain_info.bzl",
    "ActionTypeSetInfo",
    "ToolInfo",
)

visibility([
    "//cc/toolchains/...",
    "//tests/rule_based_toolchain/...",
])

def collect_provider(targets, provider):
    """Collects providers from a label list.

    Args:
        targets: (List[Target]) An attribute from attr.label_list
        provider: (provider) The provider to look up
    Returns:
        A list of the providers
    """
    return [target[provider] for target in targets]

def collect_defaultinfo(targets):
    """Collects DefaultInfo from a label list.

    Args:
        targets: (List[Target]) An attribute from attr.label_list
    Returns:
        A list of the associated defaultinfo
    """
    return collect_provider(targets, DefaultInfo)

def _make_collector(provider, field):
    def collector(targets, direct = [], transitive = []):
        # Avoid mutating what was passed in.
        transitive = transitive[:]
        for value in collect_provider(targets, provider):
            transitive.append(getattr(value, field))
        return depset(direct = direct, transitive = transitive)

    return collector

collect_action_types = _make_collector(ActionTypeSetInfo, "actions")
collect_files = _make_collector(DefaultInfo, "files")

def collect_data(ctx, targets):
    """Collects from a 'data' attribute.

    This is distinguished from collect_files by the fact that data attributes
    attributes include runfiles.

    Args:
        ctx: (Context) The ctx for the current rule
        targets: (List[Target]) A list of files or executables

    Returns:
        A depset containing all files for each of the targets, and all runfiles
        required to run them.
    """
    return ctx.runfiles(transitive_files = collect_files(targets)).merge_all([
        info.default_runfiles
        for info in collect_defaultinfo(targets)
        if info.default_runfiles != None
    ])

def collect_tools(ctx, targets, fail = fail):
    """Collects tools from a label_list.

    Each entry in the label list may either be a cc_tool or a binary.

    Args:
        ctx: (Context) The ctx for the current rule
        targets: (List[Target]) A list of targets. Each of these targets may be
          either a cc_tool or an executable.
        fail: (function) The fail function. Should only be used in tests.

    Returns:
        A List[ToolInfo], with regular executables creating custom tool info.
    """
    tools = []
    for target in targets:
        info = target[DefaultInfo]
        if ToolInfo in target:
            tools.append(target[ToolInfo])
        elif info.files_to_run != None and info.files_to_run.executable != None:
            tools.append(ToolInfo(
                label = target.label,
                exe = info.files_to_run.executable,
                runfiles = collect_data(ctx, [target]),
                requires_any_of = tuple(),
                execution_requirements = tuple(),
            ))
        else:
            fail("Expected %s to be a cc_tool or a binary rule" % target.label)

    return tools
