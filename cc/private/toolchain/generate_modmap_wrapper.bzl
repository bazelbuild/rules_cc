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
"""Generate modmap wrapper for the C++ toolchain."""

load("@rules_shell//shell:sh_binary.bzl", "sh_binary")

def _generate_modmap_wrapper_impl(ctx):
    ctx.actions.write(
        output = ctx.outputs.output,
        content = """
        set -e
        $0.runfiles/_main/{generate_modmap} $@ {compiler}
        """.format(
            generate_modmap = ctx.executable._generate_modmap.short_path,
            compiler = ctx.attr.compiler,
        ),
        is_executable = True,
    )
    return [DefaultInfo(
        executable = ctx.outputs.output,
        runfiles = ctx.runfiles(
            files = [ctx.executable._generate_modmap],
            collect_data = True,
        ),
    )]

_generate_modmap_wrapper = rule(
    implementation = _generate_modmap_wrapper_impl,
    attrs = {
        "compiler": attr.string(
            mandatory = True,
            doc = "The compiler to use.",
        ),
        "_generate_modmap": attr.label(
            default = "@bazel_tools//tools/cpp:generate-modmap",
            executable = True,
            cfg = "exec",
        ),
        "output": attr.output(
            mandatory = True,
            doc = "The output file.",
        ),
    },
    executable = True,
)

def generate_modmap_wrapper(
        name,
        compiler):
    _generate_modmap_wrapper(
        name = "gen_" + name,
        compiler = compiler,
        output = name + ".sh",
    )
    sh_binary(
        name = name,
        srcs = [":gen_" + name],
        visibility = ["//visibility:public"],
    )
