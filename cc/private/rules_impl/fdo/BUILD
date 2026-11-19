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

filegroup(
    name = "bzl_srcs",
    srcs = glob(["**/*.bzl"]),
)

filegroup(
    name = "srcs",
    srcs = glob([
        "**/*.bzl",
        "**/BUILD",
    ]),
)

alias(
    name = "fdo_rules",
    actual = ":fdo_context",
    deprecation = "Use //cc/private/rules_impl/fdo:fdo_context instead.",
)

bzl_library(
    name = "fdo_context",
    srcs = ["fdo_context.bzl"],
    deps = [
        ":fdo_prefetch_hints",
        ":fdo_profile",
        ":memprof_profile",
        ":propeller_optimize",
        "//cc:action_names",
        "//cc/common:cc_common",
        "@bazel_skylib//lib:paths",
    ],
)

bzl_library(
    name = "fdo_prefetch_hints",
    srcs = ["fdo_prefetch_hints.bzl"],
)

bzl_library(
    name = "fdo_profile",
    srcs = ["fdo_profile.bzl"],
)

bzl_library(
    name = "memprof_profile",
    srcs = ["memprof_profile.bzl"],
)

bzl_library(
    name = "propeller_optimize",
    srcs = ["propeller_optimize.bzl"],
)
