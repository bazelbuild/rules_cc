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

filegroup(
    name = "bzl_srcs",
    srcs = glob([
        "**/*.bzl",
    ]) + [
        "//cc/private/compile:bzl_srcs",
        "//cc/private/link:bzl_srcs",
        "//cc/private/rules_impl:bzl_srcs",
        "//cc/private/toolchain:bzl_srcs",
        "//cc/private/toolchain_config:bzl_srcs",
    ],
)

filegroup(
    name = "srcs",
    srcs = glob([
        "**/BUILD",
        "*.bzl",
    ]) + [
        "//cc/private/bazel7:BUILD",
        "//cc/private/compile:srcs",
        "//cc/private/link:srcs",
        "//cc/private/rules_impl:srcs",
        "//cc/private/toolchain:srcs",
        "//cc/private/toolchain_config:srcs",
    ],
)

alias(
    name = "paths_bzl",
    actual = ":paths",
    deprecation = "Use //cc/private:paths instead.",
)

bzl_library(
    name = "cc_common",
    srcs = ["cc_common.bzl"],
    deps = [
        ":cc_info",
        ":cc_internal",
        ":cc_launcher_info",
        ":cc_shared_library_hint_info",
        "//cc/common:cc_helper_internal",
        "//cc/private/compile",
        "//cc/private/compile:cc_compilation_outputs",
        "//cc/private/compile:compile_build_variables",
        "//cc/private/compile:linkstamp_compile",
        "//cc/private/compile:lto_compilation_context",
        "//cc/private/link",
        "//cc/private/link:create_extra_link_time_library",
        "//cc/private/link:create_library_to_link",
        "//cc/private/link:create_linker_input",
        "//cc/private/link:create_linking_context_from_compilation_outputs",
        "//cc/private/link:create_linkstamp",
        "//cc/private/link:dynamic_library_symlink",
        "//cc/private/link:link_build_variables",
        "//cc/private/link:lto_backends",
        "//cc/private/rules_impl:cc_toolchain_info",
        "//cc/private/rules_impl:native_cc_common",
        "//cc/private/toolchain_config:cc_toolchain_config_info",
        "//cc/private/toolchain_config:configure_features",
    ],
)

alias(
    name = "cc_info_bzl",
    actual = ":cc_info",
    deprecation = "Use //cc/private:cc_info instead.",
)

bzl_library(
    name = "cc_info",
    srcs = ["cc_info.bzl"],
    deps = [
        ":cc_internal",
        ":visibility",
        "//cc/private/link:create_extra_link_time_library",
        "@bazel_skylib//lib:paths",
    ],
)

alias(
    name = "debug_package_info_bzl",
    actual = ":debug_package_info",
    deprecation = "Use //cc/private:debug_package_info instead.",
)

alias(
    name = "cc_internal_bzl",
    actual = ":cc_internal",
    deprecation = "Use //cc/private:cc_internal instead.",
)

alias(
    name = "cc_shared_library_info_bzl",
    actual = ":cc_shared_library_info",
    deprecation = "Use //cc/private:cc_shared_library_info instead.",
)

alias(
    name = "cc_shared_library_hint_info_bzl",
    actual = ":cc_shared_library_hint_info",
    deprecation = "Use //cc/private:cc_shared_library_hint_info instead.",
)

alias(
    name = "cc_launcher_info_bzl",
    actual = ":cc_launcher_info",
    deprecation = "Use //cc/private:cc_launcher_info instead.",
)

bzl_library(
    name = "cc_launcher_info",
    srcs = ["cc_launcher_info.bzl"],
    deps = ["//cc/common:cc_helper_internal"],
)

alias(
    name = "graph_node_info_bzl",
    actual = ":graph_node_info",
    deprecation = "Use //cc/private:graph_node_info instead.",
)

alias(
    name = "objc_info_bzl",
    actual = ":objc_info",
    deprecation = "Use //cc/private:objc_info instead.",
)

alias(
    name = "visibility_bzl",
    actual = ":visibility",
    deprecation = "Use //cc/private:visibility instead.",
)

bzl_library(
    name = "visibility",
    srcs = ["visibility.bzl"],
    deps = [":cc_internal"],
)

bzl_library(
    name = "cc_internal",
    srcs = ["cc_internal.bzl"],
)

bzl_library(
    name = "cc_shared_library_hint_info",
    srcs = ["cc_shared_library_hint_info.bzl"],
)

bzl_library(
    name = "cc_shared_library_info",
    srcs = ["cc_shared_library_info.bzl"],
)

bzl_library(
    name = "debug_package_info",
    srcs = ["debug_package_info.bzl"],
)

bzl_library(
    name = "graph_node_info",
    srcs = ["graph_node_info.bzl"],
)

bzl_library(
    name = "objc_info",
    srcs = ["objc_info.bzl"],
)

bzl_library(
    name = "paths",
    srcs = ["paths.bzl"],
)
