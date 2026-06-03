# Copyright 2026 The Bazel Authors. All rights reserved.
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

"""Repository rule for importing the copy of Bazel on the user's PATH."""

def _local_bazel_import_impl(repository_ctx):
    if "windows" in repository_ctx.os.name.lower():
        bazel_real = "bazel-real.exe"
        bazel_name = "bazel.exe"
        sh_binary_name = "bazel_bin.exe"
        link_name = "bazel_link.exe"
    else:
        bazel_real = "bazel-real"
        bazel_name = "bazel"
        sh_binary_name = "bazel_bin"
        link_name = "bazel_link"

    # Prioritise bazel-real if it exists since it's much more likely to be an actual executable.
    bazel_path = repository_ctx.which(bazel_real)
    if bazel_path == None:
        bazel_path = repository_ctx.which(bazel_name)
        if bazel_path == None:
            fail("Neither '%s' or '%s' not found on PATH." % (bazel_real, bazel_name))

    repository_ctx.symlink(bazel_path, link_name)

    # sh_binary on Windows must end with .exe but we want a consistent target name, so we
    # wrap it in an alias.
    repository_ctx.file(
        "BUILD",
        executable = False,
        content = """
load({sh_binary_bzl}, "sh_binary")

sh_binary(
    name = "{bazel_bin}",
    srcs = ["{bazel_binary}"],
    visibility = ["//visibility:public"],
)

alias(
    name = "bazel",
    actual = "{bazel_bin}",
    visibility = ["//visibility:public"],
)
    """.format(
            sh_binary_bzl = repr(str(Label("@rules_shell//shell:sh_binary.bzl"))),
            bazel_bin = sh_binary_name,
            bazel_binary = link_name,
        ),
    )

local_bazel_import = repository_rule(
    implementation = _local_bazel_import_impl,
    environ = ["PATH"],
)
