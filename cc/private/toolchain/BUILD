# Copyright 2018 The Bazel Authors. All rights reserved.
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
#

load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("//cc:cc_library.bzl", "cc_library")
load("//cc/toolchains:cc_flags_supplier.bzl", "cc_flags_supplier")

package(
    default_visibility = ["//visibility:public"],
)

licenses(["notice"])

# DEPRECATED: Use //cc/compiler:cc_compiler and //cc/compiler:<compiler>_constraint instead.
# These aliases are kept for backward compatibility.
#
# Prefer using the public API in //cc/compiler:
#   @rules_cc//cc/compiler:cc_compiler (constraint_setting)
#   @rules_cc//cc/compiler:clang_constraint
#   @rules_cc//cc/compiler:gcc_constraint
#   @rules_cc//cc/compiler:msvc_constraint
#   @rules_cc//cc/compiler:clang-cl_constraint
#   @rules_cc//cc/compiler:mingw_constraint
#   @rules_cc//cc/compiler:msys_constraint

alias(
    name = "cc_compiler",
    actual = "//cc/compiler:cc_compiler",
)

alias(
    name = "clang",
    actual = "//cc/compiler:clang_constraint",
)

alias(
    name = "gcc",
    actual = "//cc/compiler:gcc_constraint",
)

alias(
    name = "msvc",
    actual = "//cc/compiler:msvc_constraint",
)

alias(
    name = "clang-cl",
    actual = "//cc/compiler:clang-cl_constraint",
)

alias(
    name = "mingw",
    actual = "//cc/compiler:mingw_constraint",
)

alias(
    name = "msys",
    actual = "//cc/compiler:msys_constraint",
)

cc_library(
    name = "malloc",
)

cc_library(
    name = "empty_cc",
    srcs = ["empty.cc"],
    alwayslink = True,
)

filegroup(
    name = "grep-includes",
    srcs = ["empty.cc"],
    deprecation = "grep-includes is always empty, you must provide your own.",
)

filegroup(
    name = "empty",
    srcs = [],
)

filegroup(
    name = "bzl_srcs",
    srcs = glob(["**/*.bzl"]),
)

filegroup(
    name = "srcs",
    srcs = glob(["**"]) + [
        "//cc/private/toolchain/test:srcs",
    ],
)

filegroup(
    name = "interface_library_builder",
    srcs = ["build_interface_so"],
)

filegroup(
    name = "link_dynamic_library",
    srcs = ["link_dynamic_library.sh"],
)

alias(
    name = "compiler",
    actual = "//cc/compiler",
)

cc_flags_supplier(name = "cc_flags")

alias(
    name = "cc_configure_bzl",
    actual = ":cc_configure",
    deprecation = "Use //cc/private/toolchain:cc_configure instead.",
)

bzl_library(
    name = "armeabi_cc_toolchain_config",
    srcs = ["armeabi_cc_toolchain_config.bzl"],
    deps = [
        "//cc:cc_toolchain_config_lib",
        "//cc/common:cc_common",
        "//cc/toolchains:cc_toolchain_config_info",
    ],
)

bzl_library(
    name = "bsd_cc_toolchain_config",
    srcs = ["bsd_cc_toolchain_config.bzl"],
    deps = [
        "//cc:action_names",
        "//cc:cc_toolchain_config_lib",
        "//cc/common:cc_common",
        "//cc/toolchains:cc_toolchain_config_info",
    ],
)

bzl_library(
    name = "cc_configure",
    srcs = ["cc_configure.bzl"],
    deps = [
        ":lib_cc_configure",
        ":unix_cc_configure",
        ":windows_cc_configure",
        "@bazel_features//:features",
    ],
)

bzl_library(
    name = "empty_cc_toolchain_config",
    srcs = ["empty_cc_toolchain_config.bzl"],
    deps = [
        "//cc/common:cc_common",
        "//cc/toolchains:cc_toolchain_config_info",
    ],
)

bzl_library(
    name = "unix_cc_configure",
    srcs = ["unix_cc_configure.bzl"],
    deps = [":lib_cc_configure"],
)

bzl_library(
    name = "unix_cc_toolchain_config",
    srcs = ["unix_cc_toolchain_config.bzl"],
    deps = [
        "//cc:action_names",
        "//cc:cc_toolchain_config_lib",
        "//cc/common:cc_common",
        "//cc/toolchains:cc_toolchain_config_info",
        "//cc/toolchains:feature_injection",
        "@bazel_features//private:bzl_files",  # copybara-uncomment-this-please
        "@bazel_skylib//rules:common_settings",
    ],
)

bzl_library(
    name = "windows_cc_configure",
    srcs = ["windows_cc_configure.bzl"],
    deps = [":lib_cc_configure"],
)

bzl_library(
    name = "windows_cc_toolchain_config",
    srcs = ["windows_cc_toolchain_config.bzl"],
    deps = [
        "//cc:action_names",
        "//cc:cc_toolchain_config_lib",
        "//cc/common:cc_common",
        "//cc/toolchains:cc_toolchain_config_info",
        "//cc/toolchains:feature_injection",
        "@bazel_features//:features",
    ],
)

bzl_library(
    name = "lib_cc_configure",
    srcs = ["lib_cc_configure.bzl"],
)
