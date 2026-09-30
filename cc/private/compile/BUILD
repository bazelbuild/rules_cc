# Copyright 2025 The Bazel Authors. All rights reserved.
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

bzl_library(
    name = "compile_bzl",
    deprecation = "Use the individual bzl_library targets instead of this one.",
    deps = [
        ":cc_compilation_helper",
        ":cc_compilation_outputs",
        ":compile",
        ":compile_action_templates",
        ":compile_build_variables",
        ":linkstamp_compile",
        ":lto_compilation_context",
    ],
)

filegroup(
    name = "bzl_srcs",
    srcs = glob([
        "**/*.bzl",
    ]),
)

filegroup(
    name = "srcs",
    srcs = glob([
        "**/*.bzl",
        "**/BUILD",
    ]),
)

bzl_library(
    name = "cc_compilation_helper",
    srcs = ["cc_compilation_helper.bzl"],
    deps = [
        "//cc/common:cc_helper_internal",
        "//cc/common:feature_names",
        "//cc/common:semantics",
        "//cc/private:cc_info",
        "//cc/private:cc_internal",
        "@bazel_skylib//lib:paths",
    ],
)

bzl_library(
    name = "cc_compilation_outputs",
    srcs = ["cc_compilation_outputs.bzl"],
    deps = [
        ":lto_compilation_context",
        "//cc/common:cc_helper_internal",
        "//cc/private:cc_internal",
    ],
)

bzl_library(
    name = "compile",
    srcs = ["compile.bzl"],
    deps = [
        ":cc_compilation_helper",
        ":cc_compilation_outputs",
        ":compile_action_templates",
        ":compile_build_variables",
        ":lto_compilation_context",
        "//cc:action_names",
        "//cc/common:cc_helper_internal",
        "//cc/common:feature_names",
        "//cc/common:semantics",
        "//cc/private:cc_info",
        "//cc/private:cc_internal",
        "@bazel_skylib//lib:paths",
    ],
)

bzl_library(
    name = "compile_action_templates",
    srcs = ["compile_action_templates.bzl"],
    deps = [
        ":cc_compilation_helper",
        ":compile_build_variables",
        "//cc/common:cc_helper_internal",
        "//cc/common:feature_names",
        "//cc/common:semantics",
        "//cc/private:cc_internal",
        "@bazel_skylib//lib:paths",
    ],
)

bzl_library(
    name = "compile_build_variables",
    srcs = ["compile_build_variables.bzl"],
    deps = [
        "//cc/common:cc_helper_internal",
        "//cc/common:feature_names",
        "//cc/private:cc_info",
        "//cc/private:cc_internal",
        "//cc/private/rules_impl:native_cc_common",
    ],
)

bzl_library(
    name = "linkstamp_compile",
    srcs = ["linkstamp_compile.bzl"],
    deps = [
        ":compile_build_variables",
        "//cc:action_names",
        "//cc/common:cc_helper_internal",
        "//cc/common:semantics",
        "//cc/private:cc_info",
        "//cc/private:cc_internal",
    ],
)

bzl_library(
    name = "lto_compilation_context",
    srcs = ["lto_compilation_context.bzl"],
    deps = [
        "//cc/common:cc_helper_internal",
        "//cc/private:cc_internal",
    ],
)
