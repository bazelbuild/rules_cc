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

load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("@bazel_skylib//rules:common_settings.bzl", "bool_flag")
load("//cc/toolchains:cc_toolchain_alias.bzl", "cc_toolchain_alias")
load(":starlark_doc_extract_helper.bzl", "starlark_doc_extract_helper")

package(default_visibility = ["//visibility:public"])

licenses(["notice"])  # Apache 2.0

filegroup(
    name = "all_files_for_testing",
    srcs = glob(["**"]) + [
        "//cc/private/rules_impl:srcs",
        "//cc/private/toolchain:srcs",
    ],
)

exports_files([
    "defs.bzl",
    "action_names.bzl",
    "system_library.bzl",
    "cc_binary.bzl",
    "cc_import.bzl",
    "cc_library.bzl",
    "cc_shared_library.bzl",
    "cc_static_library.bzl",
    "cc_test.bzl",
    "objc_import.bzl",
    "objc_library.bzl",
])

# The toolchain type used to distinguish cc toolchains.
alias(
    name = "toolchain_type",
    actual = "@bazel_tools//tools/cpp:toolchain_type",
)

filegroup(
    name = "action_names_test_files",
    testonly = True,
    srcs = [
        "BUILD",
        "action_names.bzl",
    ],
)

filegroup(
    name = "bzl_srcs",
    srcs = glob([
        "**/*.bzl",
    ]) + [
        "//cc/private:bzl_srcs",
    ],
)

filegroup(
    name = "srcs",
    testonly = 1,
    srcs = glob([
        "**/*.bzl",
        "**/BUILD",
    ]) + [
        "//cc/common:srcs",
        "//cc/compiler:srcs",
        "//cc/coverage:srcs",
        "//cc/private:srcs",
        "//cc/proto:srcs",
        "//cc/runfiles:srcs",
        "//cc/settings:srcs",
        "//cc/toolchains:srcs",
        "@bazel_skylib//:test_deps",
    ],
)

# TODO(aiuto): Find a way to strip this rule from the distribution tarball.
filegroup(
    name = "distribution",
    srcs = glob([
        "**",
    ]),
    visibility = [
        "//distro:__pkg__",
    ],
)

alias(
    name = "find_cc_toolchain_bzl",
    actual = ":find_cc_toolchain",
    deprecation = "Use //cc:find_cc_toolchain instead.",
)

alias(
    name = "action_names_bzl",
    actual = ":action_names",
    deprecation = "Use //cc:action_names instead.",
)

alias(
    name = "cc_toolchain_config_lib_bzl",
    actual = ":cc_toolchain_config_lib",
    deprecation = "Use //cc:cc_toolchain_config_lib instead.",
)

alias(
    name = "repositories_bzl",
    actual = ":repositories",
    deprecation = "Use //cc:repositories instead.",
)

bzl_library(
    name = "repositories",
    srcs = ["repositories.bzl"],
    deps = ["//cc/private/toolchain:cc_configure"],
)

alias(
    name = "defs_bzl",
    actual = ":defs",
    deprecation = "Use //cc:defs instead.",
)

bzl_library(
    name = "defs",
    srcs = ["defs.bzl"],
    deps = [
        ":cc_binary",
        ":cc_import",
        ":cc_library",
        ":cc_shared_library",
        ":cc_test",
        ":objc_import",
        ":objc_library",
        "//cc/common:cc_common",
        "//cc/common:cc_info",
        "//cc/common:debug_package_info",
        "//cc/private/rules_impl:failing_cc_proto_library",
        "//cc/toolchains:cc_flags_supplier",
        "//cc/toolchains:cc_toolchain",
        "//cc/toolchains:cc_toolchain_config_info",
        "//cc/toolchains:cc_toolchain_suite",
        "//cc/toolchains:compiler_flag",
        "//cc/toolchains:fdo_prefetch_hints",
        "//cc/toolchains:fdo_profile",
    ],
)

# Compatibility aggregate for the existing bzl_library label.
bzl_library(
    name = "cc_postmark_bzl",
    deps = [
        ":cc_postmark",
        ":cc_postmark_initializers",
    ],
)

alias(
    name = "build_settings_bzl",
    actual = ":build_settings",
    deprecation = "Use //cc:build_settings instead.",
)

bzl_library(
    name = "build_settings",
    srcs = ["build_settings.bzl"],
    deps = ["@bazel_skylib//rules:common_settings"],
)

bool_flag(
    name = "incompatible_disallow_sdk_frameworks_attributes",
    build_setting_default = False,
    scope = "universal",
)

bool_flag(
    name = "incompatible_strip_executable_safely",
    build_setting_default = False,
    scope = "universal",
)

bool_flag(
    name = "incompatible_objc_alwayslink_by_default",
    build_setting_default = False,
    scope = "universal",
)

bool_flag(
    name = "incompatible_builtin_objc_strip_action",
    build_setting_default = True,
    scope = "universal",
)

bzl_library(
    name = "core_rules",
    deprecation = "Use the individual bzl_library targets instead of this one.",
    deps = [
        ":cc_binary",
        ":cc_import",
        ":cc_library",
        ":cc_shared_library",
        ":cc_static_library",
        ":cc_test",
        ":objc_import",
        ":objc_library",
    ],
)

bzl_library(
    name = "cc_rules_extension_support",
    srcs = ["cc_rules_extension_support.bzl"],
    deps = ["@cc_compatibility_proxy//:proxy_bzl"],
)

cc_toolchain_alias(name = "current_cc_toolchain")

# Use alias, because it doesn't build on Bazel 6.
alias(
    name = "optional_current_cc_toolchain",
    actual = "//cc/private/bazel7:optional_current_cc_toolchain",
)

cc_libc_top_alias(name = "current_libc_top")

# unused target to test that we have the right bzl_library graph
starlark_doc_extract_helper(
    name = "defs_doc_extract",
    src = "defs.bzl",
    visibility = ["//visibility:private"],
    deps = [
        ":defs",
    ],
)

bzl_library(
    name = "cc_binary",
    srcs = ["cc_binary.bzl"],
    deps = ["@cc_compatibility_proxy//:proxy_bzl"],
)

bzl_library(
    name = "cc_import",
    srcs = ["cc_import.bzl"],
    deps = ["@cc_compatibility_proxy//:proxy_bzl"],
)

bzl_library(
    name = "cc_library",
    srcs = ["cc_library.bzl"],
    deps = ["@cc_compatibility_proxy//:proxy_bzl"],
)

bzl_library(
    name = "cc_shared_library",
    srcs = ["cc_shared_library.bzl"],
    deps = ["@cc_compatibility_proxy//:proxy_bzl"],
)

bzl_library(
    name = "cc_static_library",
    srcs = ["cc_static_library.bzl"],
    deps = ["@cc_compatibility_proxy//:proxy_bzl"],
)

bzl_library(
    name = "cc_test",
    srcs = ["cc_test.bzl"],  # keep
    deps = ["@cc_compatibility_proxy//:proxy_bzl"],
)

bzl_library(
    name = "extensions",
    srcs = ["extensions.bzl"],
    deps = [
        "//cc/private/toolchain:cc_configure",
        "@bazel_features//:features",
        "@bazel_features//private:bzl_files",
    ],
)

bzl_library(
    name = "find_cc_toolchain",
    srcs = ["find_cc_toolchain.bzl"],
    deps = [
        ":use_cc_toolchain",
        "//cc/common:cc_common",
    ],
)

bzl_library(
    name = "objc_import",
    srcs = ["objc_import.bzl"],
    deps = ["@cc_compatibility_proxy//:proxy_bzl"],
)

bzl_library(
    name = "objc_library",
    srcs = ["objc_library.bzl"],
    deps = ["@cc_compatibility_proxy//:proxy_bzl"],
)

bzl_library(
    name = "toolchain_utils",
    srcs = ["toolchain_utils.bzl"],
    deps = [":find_cc_toolchain"],
)

bzl_library(
    name = "action_names",
    srcs = ["action_names.bzl"],
)

bzl_library(
    name = "cc_postmark",
    srcs = ["cc_postmark.bzl"],
)

bzl_library(
    name = "cc_postmark_initializers",
    srcs = ["cc_postmark_initializers.bzl"],
)

bzl_library(
    name = "cc_toolchain_config_lib",
    srcs = ["cc_toolchain_config_lib.bzl"],
)

bzl_library(
    name = "starlark_doc_extract_helper",
    srcs = ["starlark_doc_extract_helper.bzl"],
)

bzl_library(
    name = "system_library",
    srcs = ["system_library.bzl"],
)

bzl_library(
    name = "use_cc_toolchain",
    srcs = ["use_cc_toolchain.bzl"],
)
