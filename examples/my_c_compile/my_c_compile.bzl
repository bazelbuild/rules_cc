# Copyright 2019 The Bazel Authors. All rights reserved.
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

"""Example about how to create a custom Starlark rule that just compiles C sources."""

load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "C_COMPILE_ACTION_NAME")

DISABLED_FEATURES = [
]

def _my_c_compile_impl(ctx):
    cc_toolchain = find_cpp_toolchain(ctx)
    source_file = ctx.file.src
    output_file = ctx.actions.declare_file(ctx.label.name + ".o")
    feature_configuration = cc_common.configure_features(
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = DISABLED_FEATURES + ctx.disabled_features,
    )
    c_compiler_path = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = C_COMPILE_ACTION_NAME,
    )
    c_compile_variables = cc_common.create_compile_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        source_file = source_file.path,
        output_file = output_file.path,
    )
    command_line = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = C_COMPILE_ACTION_NAME,
        variables = c_compile_variables,
    )
    env = cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = C_COMPILE_ACTION_NAME,
        variables = c_compile_variables,
    )

    ctx.actions.run(
        executable = c_compiler_path,
        arguments = command_line,
        env = env,
        inputs = depset(
            items = [source_file],
            # TODO: Use CcToolchainInfo getters when available
            # See https://github.com/bazelbuild/bazel/issues/7427.
            transitive = [ctx.attr._cc_toolchain.files],
        ),
        outputs = [output_file],
    )
    return [DefaultInfo(files = depset(items = [output_file]))]

# This rule does nothing, just propagates all cc_toolchain files.
my_c_compile = rule(
    implementation = _my_c_compile_impl,
    attrs = {
        "src": attr.label(mandatory = True, allow_single_file = True),
        "_cc_toolchain": attr.label(default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")),
    },
)
