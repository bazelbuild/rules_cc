# Copyright 2023 The Bazel Authors. All rights reserved.
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
"""Implementation of cc_tool"""

load("//cc/toolchains/impl:collect.bzl", "collect_data", "collect_provider")
load(
    ":cc_toolchain_info.bzl",
    "FeatureConstraintInfo",
    "ToolInfo",
)

def _cc_tool_impl(ctx):
    exe_info = ctx.attr.src[DefaultInfo]
    if exe_info.files_to_run != None and exe_info.files_to_run.executable != None:
        exe = exe_info.files_to_run.executable
    elif len(exe_info.files.to_list()) == 1:
        exe = exe_info.files.to_list()[0]
    else:
        fail("Expected cc_tool's src attribute to be either an executable or a single file")

    runfiles = collect_data(ctx, ctx.attr.data + [ctx.attr.src])
    tool = ToolInfo(
        label = ctx.label,
        exe = exe,
        runfiles = runfiles,
        requires_any_of = tuple(collect_provider(
            ctx.attr.requires_any_of,
            FeatureConstraintInfo,
        )),
        execution_requirements = tuple(ctx.attr.execution_requirements),
    )

    link = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.symlink(
        output = link,
        target_file = exe,
        is_executable = True,
    )
    return [
        tool,
        # This isn't required, but now we can do "bazel run <tool>", which can
        # be very helpful when debugging toolchains.
        DefaultInfo(
            files = depset([link]),
            runfiles = runfiles,
            executable = link,
        ),
    ]

cc_tool = rule(
    implementation = _cc_tool_impl,
    # @unsorted-dict-items
    attrs = {
        "src": attr.label(
            allow_files = True,
            cfg = "exec",
            doc = """The underlying binary that this tool represents.

Usually just a single prebuilt (eg. @sysroot//:bin/clang), but may be any
executable label.
""",
        ),
        "data": attr.label_list(
            allow_files = True,
            doc = "Additional files that are required for this tool to run.",
        ),
        "execution_requirements": attr.string_list(
            doc = "A list of strings that provide hints for execution environment compatibility (e.g. `requires-network`).",
        ),
        "requires_any_of": attr.label_list(
            providers = [FeatureConstraintInfo],
            doc = """This will be enabled when any of the constraints are met.

If omitted, this tool will be enabled unconditionally.
""",
        ),
    },
    provides = [ToolInfo],
    doc = """Declares a tool that can be bound to action configs.

A tool is a binary with extra metadata for the action config rule to consume
(eg. execution_requirements).

Example:
```
cc_tool(
    name = "clang_tool",
    executable = "@llvm_toolchain//:bin/clang",
    # Suppose clang needs libc to run.
    data = ["@llvm_toolchain//:lib/x86_64-linux-gnu/libc.so.6"]
)
```
""",
    executable = True,
)
