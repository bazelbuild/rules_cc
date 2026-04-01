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
"""Test helper for cc_arg_list validation."""

load("@bazel_skylib//rules:diff_test.bzl", "diff_test")
load("//cc:cc_toolchain_config_lib.bzl", "feature")
load("//cc/toolchains:cc_toolchain_info.bzl", "ArgsListInfo")
load("//cc/toolchains/impl:legacy_converter.bzl", "convert_args")

def _force_platform_transition_impl(_settings, attr):
    return {"//command_line_option:platforms": [str(attr.platform)]}

_force_platform_transition = transition(
    implementation = _force_platform_transition_impl,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)

def _generate_textproto_for_args_impl(ctx):
    out = ctx.actions.declare_file(ctx.attr.output.name)
    converted_args = [convert_args(arg) for arg in ctx.attr.actual_implementation[0][ArgsListInfo].args]
    feature_impl = feature(
        name = ctx.attr.feature_name,
        flag_sets = [fs for one_arg in converted_args for fs in one_arg.flag_sets],
        env_sets = [es for one_arg in converted_args for es in one_arg.env_sets],
    )
    strip_types = [line for line in proto.encode_text(feature_impl).splitlines() if "type_name:" not in line]

    # Ensure trailing newline.
    strip_types.append("")
    ctx.actions.write(out, "\n".join(strip_types))
    return DefaultInfo(files = depset([out]))

_generate_textproto_for_args = rule(
    implementation = _generate_textproto_for_args_impl,
    attrs = {
        "actual_implementation": attr.label(
            mandatory = True,
            providers = [ArgsListInfo],
            cfg = _force_platform_transition,
        ),
        "feature_name": attr.string(mandatory = True),
        "output": attr.output(mandatory = True),
        "platform": attr.label(mandatory = True),
    },
)

def compare_feature_implementation(name, actual_implementation, expected, platform, feature_name = None):
    """Compares the feature implementation of a given ArgsListInfo against an expected textproto.

    Args:
        name: The name of the test.
        actual_implementation: The label of the rule that provides ArgsListInfo to be tested.
        expected: The file containing the expected textproto output.
        platform: The platform to transition to for testing.
        feature_name: The name of the feature to extract from the ArgsListInfo. If None, defaults to the test name.
    """
    if feature_name == None:
        feature_name = name
    output_filename = name + ".actual.textproto"
    _generate_textproto_for_args(
        name = name + "_implementation",
        actual_implementation = actual_implementation,
        feature_name = feature_name,
        output = output_filename,
        platform = platform,
        testonly = True,
    )
    diff_test(
        name = name,
        file1 = expected,
        file2 = output_filename,
    )
