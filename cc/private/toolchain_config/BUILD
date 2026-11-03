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
    name = "toolchain_config_bzl",
    deprecation = "Use the individual bzl_library targets instead of this one.",
    deps = [
        ":cc_toolchain_config_info",
        ":configure_features",
        ":legacy_features",
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
    name = "cc_toolchain_config_info",
    srcs = ["cc_toolchain_config_info.bzl"],
    deps = [
        ":legacy_features",
        "//cc/private:cc_internal",
        "@bazel_skylib//lib:paths",
    ],
)

bzl_library(
    name = "configure_features",
    srcs = ["configure_features.bzl"],
    deps = [
        "//cc:action_names",
        "//cc/common:feature_names",
        "//cc/common:semantics",
        "//cc/private:cc_info",
    ],
)

bzl_library(
    name = "legacy_features",
    srcs = ["legacy_features.bzl"],
    deps = [
        "//cc:action_names",
        "//cc:cc_toolchain_config_lib",
    ],
)
