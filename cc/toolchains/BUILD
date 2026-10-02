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

load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

package(default_visibility = ["//visibility:public"])

# Compatibility aggregate for the existing bzl_library label.
bzl_library(
    name = "toolchain_rules",
    deps = [
        ":actions",
        ":args",
        ":args_list",
        ":artifacts",
        ":cc_flags_supplier",
        ":cc_toolchain",
        ":cc_toolchain_alias",
        ":cc_toolchain_config_info",
        ":cc_toolchain_info",
        ":cc_toolchain_suite",
        ":compiler_flag",
        ":directory_tool",
        ":fdo_prefetch_hints",
        ":fdo_profile",
        ":feature",
        ":feature_constraint",
        ":feature_injection",
        ":feature_set",
        ":legacy_file_group",
        ":legacy_tool",
        ":libc_flag",
        ":make_variable",
        ":memprof_profile",
        ":mutually_exclusive_category",
        ":nested_args",
        ":propeller_optimize",
        ":providers",
        ":tool",
        ":tool_capability",
        ":tool_map",
        ":toolchain",
        ":toolchain_config_utils",
    ],
)

alias(
    name = "cc_toolchain_config_info_bzl",
    actual = ":cc_toolchain_config_info",
    deprecation = "Use //cc/toolchains:cc_toolchain_config_info instead.",
)

bzl_library(
    name = "cc_toolchain_config_info",
    srcs = ["cc_toolchain_config_info.bzl"],
    deps = ["@cc_compatibility_proxy//:symbols_bzl"],
)

filegroup(
    name = "srcs",
    srcs = glob([
        "**/*.bzl",
        "**/BUILD",
    ]) + [
        "//cc/toolchains/actions:srcs",
        "//cc/toolchains/args:srcs",
        "//cc/toolchains/artifacts:srcs",
        "//cc/toolchains/features:srcs",
        "//cc/toolchains/impl:srcs",
        "//cc/toolchains/variables:srcs",
    ],
)

bzl_library(
    name = "actions",
    srcs = ["actions.bzl"],
    deps = [
        ":cc_toolchain_info",
        "//cc/toolchains/impl:collect",
    ],
)

bzl_library(
    name = "args",
    srcs = ["args.bzl"],
    deps = [
        ":cc_toolchain_info",
        "//cc/private:paths",
        "//cc/toolchains/impl:args_utils",
        "//cc/toolchains/impl:collect",
        "//cc/toolchains/impl:nested_args",
        "@bazel_skylib//rules/directory:providers",
    ],
)

bzl_library(
    name = "args_list",
    srcs = ["args_list.bzl"],
    deps = [
        ":cc_toolchain_info",
        "//cc/toolchains/impl:collect",
    ],
)

bzl_library(
    name = "artifacts",
    srcs = ["artifacts.bzl"],
    deps = [":cc_toolchain_info"],
)

bzl_library(
    name = "cc_flags_supplier",
    srcs = ["cc_flags_supplier.bzl"],
    deps = [
        "//cc:action_names",
        "//cc:find_cc_toolchain",
        "//cc/private/rules_impl:cc_flags_supplier_lib",
    ],
)

bzl_library(
    name = "cc_toolchain",
    srcs = ["cc_toolchain.bzl"],
    deps = ["@cc_compatibility_proxy//:proxy_bzl"],
)

bzl_library(
    name = "cc_toolchain_alias",
    srcs = ["cc_toolchain_alias.bzl"],
    deps = ["@cc_compatibility_proxy//:proxy_bzl"],
)

bzl_library(
    name = "compiler_flag",
    srcs = ["compiler_flag.bzl"],
    deps = ["//cc:find_cc_toolchain"],
)

bzl_library(
    name = "directory_tool",
    srcs = ["directory_tool.bzl"],
    deps = [
        ":tool",
        "@bazel_skylib//rules/directory:glob",
    ],
)

bzl_library(
    name = "fdo_prefetch_hints",
    srcs = ["fdo_prefetch_hints.bzl"],
    deps = ["@cc_compatibility_proxy//:proxy_bzl"],
)

bzl_library(
    name = "fdo_profile",
    srcs = ["fdo_profile.bzl"],
    deps = ["@cc_compatibility_proxy//:proxy_bzl"],
)

bzl_library(
    name = "feature",
    srcs = ["feature.bzl"],
    deps = [
        ":cc_toolchain_info",
        "//cc/toolchains/impl:collect",
    ],
)

bzl_library(
    name = "feature_constraint",
    srcs = ["feature_constraint.bzl"],
    deps = [
        ":cc_toolchain_info",
        "//cc/toolchains/impl:collect",
    ],
)

bzl_library(
    name = "feature_injection",
    srcs = ["feature_injection.bzl"],
    deps = [
        ":cc_toolchain_info",
        "//cc/toolchains/impl:legacy_converter",
    ],
)

bzl_library(
    name = "feature_set",
    srcs = ["feature_set.bzl"],
    deps = [
        ":cc_toolchain_info",
        "//cc/toolchains/impl:collect",
    ],
)

bzl_library(
    name = "legacy_tool",
    srcs = ["legacy_tool.bzl"],
    deps = [":cc_toolchain_info"],
)

bzl_library(
    name = "libc_flag",
    srcs = ["libc_flag.bzl"],
    deps = [
        "//cc:find_cc_toolchain",
        "//cc/toolchains/impl:libc_version",
    ],
)

bzl_library(
    name = "make_variable",
    srcs = ["make_variable.bzl"],
    deps = [":cc_toolchain_info"],
)

bzl_library(
    name = "memprof_profile",
    srcs = ["memprof_profile.bzl"],
    deps = ["@cc_compatibility_proxy//:proxy_bzl"],
)

bzl_library(
    name = "mutually_exclusive_category",
    srcs = ["mutually_exclusive_category.bzl"],
    deps = [":cc_toolchain_info"],
)

bzl_library(
    name = "nested_args",
    srcs = ["nested_args.bzl"],
    deps = [
        ":cc_toolchain_info",
        "//cc/toolchains/impl:nested_args",
    ],
)

bzl_library(
    name = "propeller_optimize",
    srcs = ["propeller_optimize.bzl"],
    deps = ["@cc_compatibility_proxy//:proxy_bzl"],
)

bzl_library(
    name = "providers",
    srcs = ["providers.bzl"],
    deps = [":cc_toolchain_info"],
)

bzl_library(
    name = "tool",
    srcs = ["tool.bzl"],
    deps = [
        ":cc_toolchain_info",
        "//cc/toolchains/impl:collect",
        "//cc/toolchains/impl:label_utils",
        "//cc/toolchains/impl:nested_args",
        "@bazel_skylib//rules/directory:providers",
    ],
)

bzl_library(
    name = "tool_capability",
    srcs = ["tool_capability.bzl"],
    deps = [":cc_toolchain_info"],
)

bzl_library(
    name = "tool_map",
    srcs = ["tool_map.bzl"],
    deps = [
        ":cc_toolchain_info",
        "//cc/toolchains/impl:collect",
        "//cc/toolchains/impl:label_utils",
        "@bazel_features//:features",
    ],
)

bzl_library(
    name = "toolchain",
    srcs = ["toolchain.bzl"],
    deps = [
        ":cc_toolchain",
        ":legacy_file_group",
        "//cc/toolchains/impl:toolchain_config",
        "@bazel_features//:features",
    ],
)

bzl_library(
    name = "toolchain_config_utils",
    srcs = ["toolchain_config_utils.bzl"],
    deps = [
        "//cc/private/toolchain:cc_configure",
        "//cc/private/toolchain:lib_cc_configure",
        "//cc/private/toolchain:windows_cc_configure",
    ],
)

bzl_library(
    name = "cc_toolchain_info",
    srcs = ["cc_toolchain_info.bzl"],
)

bzl_library(
    name = "cc_toolchain_suite",
    srcs = ["cc_toolchain_suite.bzl"],
)

bzl_library(
    name = "legacy_file_group",
    srcs = ["legacy_file_group.bzl"],
)
