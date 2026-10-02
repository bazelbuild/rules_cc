# This directory contains implementations of starlark functions that contain
# complex logic. The objective is to keep the rules themselves as simple as
# possible, so that we can perform very thorough testing on the implementation.

# I wanted to call it private / internal, but then buildifier complains about
# referencing it from the tests directory.

load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

package(default_visibility = ["//visibility:public"])

exports_files(
    ["documented_api.bzl"],
    visibility = ["//docs:__pkg__"],
)

bzl_library(
    name = "toolchain_impl_rules",
    deprecation = "Use the individual bzl_library targets instead of this one.",
    deps = [
        ":args_utils",
        ":cc_artifact_category",
        ":collect",
        ":documented_api",
        ":external_feature",
        ":label_utils",
        ":legacy_converter",
        ":libc_version",
        ":markdown_helpers",
        ":nested_args",
        ":toolchain_config",
        ":toolchain_config_info",
        ":variables",
    ],
)

config_setting(
    name = "darwin_x86_64",
    constraint_values = [
        "@platforms//cpu:x86_64",
        "@platforms//os:macos",
    ],
)

config_setting(
    name = "darwin_aarch64",
    constraint_values = [
        "@platforms//cpu:aarch64",
        "@platforms//os:macos",
    ],
)

config_setting(
    name = "linux_x86_64",
    constraint_values = [
        "@platforms//cpu:x86_64",
        "@platforms//os:linux",
    ],
)

config_setting(
    name = "linux_aarch64",
    constraint_values = [
        "@platforms//cpu:aarch64",
        "@platforms//os:linux",
    ],
)

config_setting(
    name = "windows_x86_32",
    constraint_values = [
        "@platforms//os:windows",
        "@platforms//cpu:x86_32",
    ],
)

config_setting(
    name = "windows_x86_64",
    constraint_values = [
        "@platforms//os:windows",
        "@platforms//cpu:x86_64",
    ],
)

filegroup(
    name = "srcs",
    srcs = glob(["**"]),
)

bzl_library(
    name = "args_utils",
    srcs = ["args_utils.bzl"],
    deps = [":variables"],
)

bzl_library(
    name = "cc_artifact_category",
    srcs = ["cc_artifact_category.bzl"],
    deps = ["//cc/toolchains:cc_toolchain_info"],
)

bzl_library(
    name = "collect",
    srcs = ["collect.bzl"],
    deps = ["//cc/toolchains:cc_toolchain_info"],
)

bzl_library(
    name = "documented_api",
    srcs = ["documented_api.bzl"],
    deps = [
        ":external_feature",
        ":variables",
        "//cc/toolchains:actions",
        "//cc/toolchains:args",
        "//cc/toolchains:args_list",
        "//cc/toolchains:artifacts",
        "//cc/toolchains:feature",
        "//cc/toolchains:feature_constraint",
        "//cc/toolchains:feature_set",
        "//cc/toolchains:make_variable",
        "//cc/toolchains:mutually_exclusive_category",
        "//cc/toolchains:nested_args",
        "//cc/toolchains:tool",
        "//cc/toolchains:tool_capability",
        "//cc/toolchains:tool_map",
        "//cc/toolchains:toolchain",
    ],
)

bzl_library(
    name = "external_feature",
    srcs = ["external_feature.bzl"],
    deps = ["//cc/toolchains:cc_toolchain_info"],
)

bzl_library(
    name = "legacy_converter",
    srcs = ["legacy_converter.bzl"],
    deps = ["//cc:cc_toolchain_config_lib"],
)

bzl_library(
    name = "nested_args",
    srcs = ["nested_args.bzl"],
    deps = [
        ":collect",
        "//cc:cc_toolchain_config_lib",
        "//cc/toolchains:cc_toolchain_info",
        "@bazel_features//:features",
        "@bazel_skylib//rules:common_settings",
        "@bazel_skylib//rules/directory:providers",
    ],
)

bzl_library(
    name = "toolchain_config",
    srcs = ["toolchain_config.bzl"],
    deps = [
        ":collect",
        ":legacy_converter",
        ":toolchain_config_info",
        "//cc/common:cc_common",
        "//cc/toolchains:cc_toolchain_info",
    ],
)

bzl_library(
    name = "toolchain_config_info",
    srcs = ["toolchain_config_info.bzl"],
    deps = [
        ":args_utils",
        ":collect",
        "//cc/toolchains:cc_toolchain_info",
    ],
)

bzl_library(
    name = "variables",
    srcs = ["variables.bzl"],
    deps = [
        ":collect",
        "//cc/toolchains:cc_toolchain_info",
    ],
)

bzl_library(
    name = "label_utils",
    srcs = ["label_utils.bzl"],
)

bzl_library(
    name = "libc_version",
    srcs = ["libc_version.bzl"],
)

bzl_library(
    name = "markdown_helpers",
    srcs = ["markdown_helpers.bzl"],
)
