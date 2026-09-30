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
    name = "link_bzl",
    deprecation = "Use the individual bzl_library targets instead of this one.",
    deps = [
        ":cc_linking_helper",
        ":collect_solib_dirs",
        ":cpp_link_action",
        ":create_extra_link_time_library",
        ":create_libraries_to_link_values",
        ":create_library_to_link",
        ":create_linker_input",
        ":create_linking_context_from_compilation_outputs",
        ":create_linkstamp",
        ":dynamic_library_symlink",
        ":finalize_link_action",
        ":link",
        ":link_build_variables",
        ":lto_backends",
        ":lto_indexing_action",
        ":target_types",
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
    name = "cc_linking_helper",
    srcs = ["cc_linking_helper.bzl"],
    deps = [
        ":cpp_link_action",
        ":create_library_to_link",
        ":dynamic_library_symlink",
        ":lto_indexing_action",
        ":target_types",
        "//cc/common:cc_helper_internal",
        "//cc/common:feature_names",
        "//cc/private:cc_internal",
        "//cc/private/compile:cc_compilation_outputs",
        "@bazel_skylib//lib:paths",
    ],
)

bzl_library(
    name = "collect_solib_dirs",
    srcs = ["collect_solib_dirs.bzl"],
    deps = [
        ":target_types",
        "//cc/common:cc_helper_internal",
        "//cc/common:feature_names",
        "@bazel_skylib//lib:paths",
    ],
)

bzl_library(
    name = "cpp_link_action",
    srcs = ["cpp_link_action.bzl"],
    deps = [
        ":dynamic_library_symlink",
        ":finalize_link_action",
        ":link_build_variables",
        ":lto_backends",
        ":target_types",
        "//cc/common:cc_helper_internal",
        "//cc/private/rules_impl:native_cc_common",
        "@bazel_skylib//lib:paths",
    ],
)

bzl_library(
    name = "create_extra_link_time_library",
    srcs = ["create_extra_link_time_library.bzl"],
    deps = [
        "//cc/private:cc_internal",
        "//cc/private:visibility",
    ],
)

bzl_library(
    name = "create_libraries_to_link_values",
    srcs = ["create_libraries_to_link_values.bzl"],
    deps = ["//cc/common:cc_helper_internal"],
)

bzl_library(
    name = "create_library_to_link",
    srcs = ["create_library_to_link.bzl"],
    deps = [
        ":dynamic_library_symlink",
        ":lto_backends",
        "//cc/common:cc_helper_internal",
        "//cc/common:feature_names",
        "//cc/private:cc_internal",
        "//cc/private/compile:lto_compilation_context",
        "@bazel_skylib//lib:paths",
    ],
)

bzl_library(
    name = "create_linker_input",
    srcs = ["create_linker_input.bzl"],
    deps = ["//cc/private:cc_internal"],
)

bzl_library(
    name = "create_linking_context_from_compilation_outputs",
    srcs = ["create_linking_context_from_compilation_outputs.bzl"],
    deps = [
        ":cc_linking_helper",
        ":create_linker_input",
        ":target_types",
        "//cc/private:cc_info",
        "//cc/private:cc_internal",
    ],
)

bzl_library(
    name = "create_linkstamp",
    srcs = ["create_linkstamp.bzl"],
    deps = ["//cc/common:cc_helper_internal"],
)

bzl_library(
    name = "dynamic_library_symlink",
    srcs = ["dynamic_library_symlink.bzl"],
    deps = [
        "//cc/common:cc_helper_internal",
        "//cc/private:cc_internal",
        "@bazel_skylib//lib:paths",
    ],
)

bzl_library(
    name = "finalize_link_action",
    srcs = ["finalize_link_action.bzl"],
    deps = [
        ":collect_solib_dirs",
        ":create_libraries_to_link_values",
        ":link_build_variables",
        ":target_types",
        "//cc/common:feature_names",
        "//cc/common:semantics",
        "//cc/private:cc_internal",
        "//cc/private/compile:linkstamp_compile",
        "//cc/private/rules_impl:native_cc_common",
        "@bazel_features//:features",
    ],
)

bzl_library(
    name = "link",
    srcs = ["link.bzl"],
    deps = [
        ":cc_linking_helper",
        ":target_types",
        "//cc/common:feature_names",
        "//cc/private:cc_internal",
        "//cc/private/compile:cc_compilation_outputs",
    ],
)

bzl_library(
    name = "link_build_variables",
    srcs = ["link_build_variables.bzl"],
    deps = [
        "//cc/common:cc_helper_internal",
        "//cc/common:feature_names",
        "//cc/private:cc_internal",
    ],
)

bzl_library(
    name = "lto_backends",
    srcs = ["lto_backends.bzl"],
    deps = [
        "//cc/common:cc_helper_internal",
        "//cc/common:feature_names",
        "//cc/private:cc_internal",
        "//cc/private/rules_impl:native_cc_common",
        "@bazel_skylib//lib:paths",
    ],
)

bzl_library(
    name = "lto_indexing_action",
    srcs = ["lto_indexing_action.bzl"],
    deps = [
        ":finalize_link_action",
        ":link_build_variables",
        ":lto_backends",
        ":target_types",
        "//cc/common:cc_helper_internal",
        "//cc/common:feature_names",
        "//cc/private:cc_internal",
        "//cc/private/compile:lto_compilation_context",
        "@bazel_features//:features",
    ],
)

bzl_library(
    name = "target_types",
    srcs = ["target_types.bzl"],
    deps = [
        "//cc:action_names",
        "//cc/common:cc_helper_internal",
    ],
)
