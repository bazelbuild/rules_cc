load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

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
    visibility = ["//visibility:public"],
)

filegroup(
    name = "srcs",
    srcs = glob([
        "**/*.bzl",
        "**/BUILD",
    ]) + [
        "//cc/private/rules_impl:srcs",
        "//cc/private/toolchain:srcs",
    ],
    visibility = ["//visibility:public"],
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

cc_toolchain_alias(name = "current_cc_toolchain")

cc_host_toolchain_alias(name = "current_cc_host_toolchain")

cc_libc_top_alias(name = "current_libc_top")

bzl_library(
    name = "action_names",
    srcs = ["action_names.bzl"],
)

bzl_library(
    name = "cc_toolchain_config_lib",
    srcs = ["cc_toolchain_config_lib.bzl"],
)

bzl_library(
    name = "defs",
    srcs = ["defs.bzl"],
    deps = [
        "@rules_cc//cc/private/rules_impl:cc_flags_supplier",
        "@rules_cc//cc/private/rules_impl:compiler_flag",
    ],
)

bzl_library(
    name = "find_cc_toolchain",
    srcs = ["find_cc_toolchain.bzl"],
)

bzl_library(
    name = "repositories",
    srcs = ["repositories.bzl"],
    # Temporarily omit @bazel_tools targets that can't be imported because they
    # are not exported in the production version of Bazel.
    # https://github.com/bazelbuild/bazel/pull/12258
    deps = [
        #"@bazel_tools//tools/build_defs/repo:http.bzl",
        "@rules_cc//cc/private/toolchain:cc_configure",
    ],  # keep
)

bzl_library(
    name = "system_library",
    srcs = ["system_library.bzl"],
)

bzl_library(
    name = "toolchain_utils",
    srcs = ["toolchain_utils.bzl"],
)

bzl_library(
    name = "version",
    srcs = ["version.bzl"],
)
