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

load("@rules_cc//cc/toolchains:args.bzl", "cc_args")
load("@rules_cc//cc/toolchains:toolchain.bzl", "cc_toolchain")

package(default_visibility = ["//visibility:public"])

licenses(["notice"])

# For now, each toolchain is only declared to be compatible
# when exec_platform == target_platform.
PLATFORMS = {
    "linux-x86_64": [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
    ],
}

cc_args(
    name = "warnings",
    actions = [
        "@rules_cc//cc/toolchains/actions:c_compile",
        "@rules_cc//cc/toolchains/actions:cpp_compile_actions",
    ],
    args = [
        "-Werror",
        "-Wall",
        "-Wextra",
        "-Wpedantic",
    ],
)

cc_args(
    name = "no_canonical_prefixes",
    actions = [
        "@rules_cc//cc/toolchains/actions:c_compile",
        "@rules_cc//cc/toolchains/actions:cpp_compile_actions",
    ],
    args = ["-no-canonical-prefixes"],
)

[
    cc_toolchain(
        name = "host-{}-config".format(platform_name),
        args = select({
            "@platforms//os:linux": [
                "@linux_sysroot//:sysroot",
            ],
            "//conditions:default": [],
        }) + [
            ":no_canonical_prefixes",
            ":warnings",
        ],
        enabled_features = ["@rules_cc//cc/toolchains/args:experimental_replace_legacy_action_config_features"],
        known_features = ["@rules_cc//cc/toolchains/args:experimental_replace_legacy_action_config_features"],
        target_compatible_with = constraints,
        tool_map = "@clang-{}//:all_tools".format(platform_name),
    )
    for platform_name, constraints in PLATFORMS.items()
]

[
    toolchain(
        name = "host-{}".format(platform_name),
        exec_compatible_with = constraints,
        target_compatible_with = constraints,
        toolchain = ":host-{}-config".format(platform_name),
        toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
    )
    for platform_name, constraints in PLATFORMS.items()
]
