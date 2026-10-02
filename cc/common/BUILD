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
load("//cc:starlark_doc_extract_helper.bzl", "starlark_doc_extract_helper")

package(default_visibility = ["//visibility:public"])

exports_files(
    [
        "cc_common.bzl",
        "cc_info.bzl",
    ],
    visibility = ["//visibility:public"],
)

bzl_library(
    name = "common",
    deprecation = "Use the individual bzl_library targets instead of this one.",
    deps = [
        ":cc_common",
        ":cc_helper",
        ":cc_helper_internal",
        ":cc_info",
        ":cc_shared_library_hint_info",
        ":debug_package_info",
        ":objc_info",
        ":semantics",
    ],
)

alias(
    name = "cc_helper_bzl",
    actual = ":cc_helper",
    deprecation = "Use //cc/common:cc_helper instead.",
)

bzl_library(
    name = "cc_helper",
    srcs = ["cc_helper.bzl"],
    deps = [
        ":cc_common",
        ":cc_helper_internal",
        ":cc_info",
        ":feature_names",
        "//cc:action_names",
        "//cc:find_cc_toolchain",
        "//cc/private:paths",
        "//cc/private:visibility",
        "//cc/private/rules_impl:objc_common",
    ],
)

alias(
    name = "cc_shared_library_info_bzl",
    actual = ":cc_shared_library_info",
    deprecation = "Use //cc/common:cc_shared_library_info instead.",
)

bzl_library(
    name = "cc_shared_library_info",
    srcs = ["cc_shared_library_info.bzl"],
    deps = ["@cc_compatibility_proxy//:symbols_bzl"],
)

alias(
    name = "semantics_bzl",
    actual = ":semantics",
    deprecation = "Use //cc/common:semantics instead.",
    visibility = ["//cc:__subpackages__"],
)

bzl_library(
    name = "semantics",
    srcs = ["semantics.bzl"],
    deps = [":cc_helper_internal"],
)

alias(
    name = "cc_helper_internal_bzl",
    actual = ":cc_helper_internal",
    deprecation = "Use //cc/common:cc_helper_internal instead.",
    visibility = ["//cc:__subpackages__"],
)

bzl_library(
    name = "cc_helper_internal",
    srcs = ["cc_helper_internal.bzl"],
    deps = [
        ":feature_names",
        "//cc/private:paths",
        "//cc/private:visibility",
        "@bazel_skylib//lib:paths",
    ],
)

alias(
    name = "cc_debug_helper_bzl",
    actual = ":cc_debug_helper",
    deprecation = "Use //cc/common:cc_debug_helper instead.",
)

bzl_library(
    name = "cc_debug_helper",
    srcs = ["cc_debug_helper.bzl"],
    deps = [
        ":cc_common",
        ":cc_helper",
        "//cc:action_names",
        "//cc:find_cc_toolchain",
        "//cc/private:visibility",
    ],
)

filegroup(
    name = "srcs",
    srcs = glob([
        "**/*.bzl",
        "**/BUILD",
    ]),
)

# unused targets to test that we have the right bzl_library graph
[starlark_doc_extract_helper(
    name = f + "_doc_extract",
    src = f,
    visibility = ["//visibility:private"],
    deps = [
        ":common",
    ],
) for f in glob(
    ["*.bzl"],
    exclude = [
        "cc_helper.bzl",
        "cc_debug_helper.bzl",
        "semantics.bzl",
        "cc_helper_internal.bzl",
        "cc_shared_library_info.bzl",
    ],
)]

alias(
    name = "feature_names_bzl",
    actual = ":feature_names",
    deprecation = "Use //cc/common:feature_names instead.",
)

bzl_library(
    name = "cc_common",
    srcs = ["cc_common.bzl"],
    deps = ["@cc_compatibility_proxy//:symbols_bzl"],
)

bzl_library(
    name = "cc_info",
    srcs = ["cc_info.bzl"],
    deps = ["@cc_compatibility_proxy//:symbols_bzl"],
)

bzl_library(
    name = "cc_shared_library_hint_info",
    srcs = ["cc_shared_library_hint_info.bzl"],
    deps = [":cc_common"],
)

bzl_library(
    name = "debug_package_info",
    srcs = ["debug_package_info.bzl"],
    deps = ["@cc_compatibility_proxy//:symbols_bzl"],
)

bzl_library(
    name = "objc_info",
    srcs = ["objc_info.bzl"],
    deps = ["@cc_compatibility_proxy//:symbols_bzl"],
)

bzl_library(
    name = "feature_names",
    srcs = ["feature_names.bzl"],
)
