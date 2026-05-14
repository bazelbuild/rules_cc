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

load("//cc:cc_toolchain_config_lib.bzl", "feature")
load("//cc/toolchains:cc_toolchain_info.bzl", "ArgsListInfo")
load("//cc/toolchains/impl:legacy_converter.bzl", "convert_args")
load("//tests/rule_based_toolchain:testing_rules.bzl", "analysis_test")

def _feature_textproto(feature_impl):
    strip_types = [
        line
        for line in proto.encode_text(feature_impl).splitlines()
        if "type_name:" not in line
    ]

    # Ensure trailing newline.
    strip_types.append("")
    return "\n".join(strip_types)

def _compare_feature_implementation_impl(env, target):
    converted_args = [convert_args(arg) for arg in target[ArgsListInfo].args]
    feature_impl = feature(
        name = env.ctx.attr.feature_name,
        flag_sets = [fs for one_arg in converted_args for fs in one_arg.flag_sets],
        env_sets = [es for one_arg in converted_args for es in one_arg.env_sets],
    )
    env.expect.that_str(_feature_textproto(feature_impl)).equals(env.ctx.attr.expected)

def compare_feature_implementation(name, actual_implementation, expected, platform, feature_name = None):
    """Compares the feature implementation of a given ArgsListInfo against an expected textproto.

    Args:
        name: The name of the test.
        actual_implementation: The label of the rule that provides ArgsListInfo to be tested.
        expected: The expected textproto output.
        platform: The platform to test with.
        feature_name: The name of the feature to extract from the ArgsListInfo. If None, defaults to the test name.
    """
    if feature_name == None:
        feature_name = name
    analysis_test(
        name = name,
        target = actual_implementation,
        impl = _compare_feature_implementation_impl,
        attrs = {
            "expected": attr.string(mandatory = True),
            "feature_name": attr.string(mandatory = True),
            "target": {
                "providers": [ArgsListInfo],
            },
        },
        attr_values = {
            "expected": expected,
            "feature_name": feature_name,
            "size": "small",
        },
        config_settings = {
            "//command_line_option:platforms": [native.package_relative_label(platform)],
        },
    )
