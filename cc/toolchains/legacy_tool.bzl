# Copyright 2026 The Bazel Authors. All rights reserved.
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
"""Implementation of cc_legacy_tool"""

load(":cc_toolchain_info.bzl", "LegacyToolInfo")

def _cc_legacy_tool_impl(ctx):
    return [LegacyToolInfo(
        label = ctx.label,
        name = ctx.attr.tool_name,
        path = ctx.attr.path,
    )]

cc_legacy_tool = rule(
    implementation = _cc_legacy_tool_impl,
    attrs = {
        "tool_name": attr.string(
            mandatory = True,
            doc = """The name of the tool (eg. "gcc", "ar", "ld", "strip").

This corresponds to the tool name used by Bazel's legacy toolchain resolution.
""",
        ),
        "path": attr.string(
            mandatory = True,
            doc = """The filesystem path to the tool.

Can be an absolute path (for non-hermetic toolchains) or a relative path
starting from the package that provides the toolchain.
""",
        ),
    },
    provides = [LegacyToolInfo],
    doc = """Declares a tool by filesystem path for use in legacy toolchain configurations.

`cc_legacy_tool` allows specifying tools by their filesystem path rather than as
Bazel targets. This is useful where bazel doesn't handle relative paths well.

These tools are passed via the `legacy_tools` attribute of `cc_toolchain`.

Example:
```
load("@rules_cc//cc/toolchains:legacy_tool.bzl", "cc_legacy_tool")

cc_legacy_tool(
    name = "gcov",
    tool_name = "gcov",
    path = "/usr/bin/gcov",
)
```
""",
)
