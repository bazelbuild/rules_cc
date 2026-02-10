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

load("//cc/toolchains:args.bzl", "cc_args")
load("//cc/toolchains:tool.bzl", "cc_tool")
load("//cc/toolchains:tool_map.bzl", "cc_tool_map")
load("//cc/toolchains:toolchain.bzl", "cc_toolchain")
load(":validate_static_library_env_test.bzl", "maybe_define_validate_static_library_env_targets")

package(default_visibility = ["//visibility:private"])

constraint_setting(name = "toolchain_selector")

constraint_value(
    name = "use_test_toolchain",
    constraint_setting = ":toolchain_selector",
)

platform(
    name = "test_platform",
    constraint_values = [":use_test_toolchain"],
)

cc_tool(
    name = "archive_tool",
    src = "tools/archive_tool.sh",
)

cc_tool(
    name = "validate_tool",
    src = "tools/validate_tool.sh",
)

cc_tool_map(
    name = "tool_map",
    tools = {
        "//cc/toolchains/actions:cpp_link_static_library": ":archive_tool",
        "//cc/toolchains/actions:validate_static_library": ":validate_tool",
    },
)

cc_args(
    name = "archive_output_arg",
    actions = ["//cc/toolchains/actions:cpp_link_static_library"],
    args = ["{output_execpath}"],
    format = {
        "output_execpath": "//cc/toolchains/variables:output_execpath",
    },
    requires_not_none = "//cc/toolchains/variables:output_execpath",
)

cc_args(
    name = "validate_static_library_env_args",
    actions = ["//cc/toolchains/actions:validate_static_library"],
    env = {
        "VALIDATE_STATIC_LIBRARY_ENV": "expected",
    },
)

cc_toolchain(
    name = "test_cc_toolchain",
    args = [
        ":archive_output_arg",
        ":validate_static_library_env_args",
    ],
    tool_map = ":tool_map",
)

toolchain(
    name = "test_cc_toolchain_registration",
    target_compatible_with = [":use_test_toolchain"],
    toolchain = ":test_cc_toolchain",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)

maybe_define_validate_static_library_env_targets()
