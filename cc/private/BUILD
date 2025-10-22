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

filegroup(
    name = "srcs",
    srcs = glob([
        "**/BUILD",
        "*.bzl",
    ]) + [
        "//cc/private/compile:srcs",
        "//cc/private/link:srcs",
        "//cc/private/rules_impl:srcs",
        "//cc/private/toolchain:srcs",
        "//cc/private/toolchain_config:srcs",
    ],
    visibility = ["//visibility:public"],
)

bzl_library(
    name = "paths_bzl",
    srcs = ["paths.bzl"],
    visibility = ["//cc:__subpackages__"],
)

bzl_library(
    name = "debug_package_info_bzl",
    srcs = ["debug_package_info.bzl"],
    visibility = ["//cc:__subpackages__"],
)

bzl_library(
    name = "cc_internal_bzl",
    srcs = ["cc_internal.bzl"],
    visibility = ["//cc:__subpackages__"],
)

bzl_library(
    name = "cc_shared_library_hint_info_bzl",
    srcs = ["cc_shared_library_hint_info.bzl"],
    visibility = ["//cc:__subpackages__"],
)

bzl_library(
    name = "cc_launcher_info_bzl",
    srcs = ["cc_launcher_info.bzl"],
    visibility = ["//cc:__subpackages__"],
    deps = ["//cc/common"],
)
