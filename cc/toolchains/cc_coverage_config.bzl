# Copyright 2025 The Bazel Authors. All rights reserved.
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

"""Rules to configure cc coverage collection."""

load("//cc/toolchains/impl:collect.bzl", "collect_data")
load(":cc_toolchain_info.bzl", "CoverageTypeInfo", "CoverageConfigInfo")

def _cc_coverage_config_impl(ctx):
    exe_info = ctx.attr.src[DefaultInfo]
    if exe_info.files_to_run != None and exe_info.files_to_run.executable != None:
        exe = exe_info.files_to_run.executable
    elif len(exe_info.files.to_list()) == 1:
        exe = exe_info.files.to_list()[0]
    else:
        fail("Expected cc_coverage_config's src attribute to be either an executable or a single file")

    runfiles = collect_data(ctx, ctx.attr.data + [ctx.attr.src])
    config = CoverageConfigInfo(
        label = ctx.label,
        type = ctx.attr.type[CoverageTypeInfo],
        exe = exe,
        runfiles = runfiles,
    )

    link = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.symlink(
        output = link,
        target_file = exe,
        is_executable = True,
    )
    return [
        config,
        # This isn't required, but now we can do "bazel run <config>", which can
        # be very helpful when debugging toolchains.
        DefaultInfo(
            files = depset([link]),
            runfiles = runfiles,
            executable = link,
        ),
    ]

cc_coverage_config = rule(
    implementation = _cc_coverage_config_impl,
    attrs = {
        "type": attr.label(
            mandatory = True,
            providers = [
                CoverageTypeInfo,
            ],
            doc = """
The type of coverage this config is for (e.g., gcov).

See `@rules_cc//cc/coverage/type` for a list of supported types.
"""
        ),
        "src": attr.label(
            mandatory = True,
            allow_files = True,
            cfg = "exec",
            doc = """
The tool to collect coverage with.
"""
        ),
        "data": attr.label_list(
            mandatory = False,
            allow_files = True,
            doc = """
Additional files that are required for this coverage config to run.
""",
        ),
    },
    doc = """
Defines the configuration to collect CC coverage.

Example:
```
load("//cc/toolchains:cc_coverage_config.bzl", "cc_coverage_config")

cc_coverage_config(
    name = "gcov",
    type = "//cc/coverage/type:gcov",
    src = "bin/gcov",
)
```
""",
    provides = [
        CoverageConfigInfo,
    ],
)
