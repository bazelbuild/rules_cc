# Copyright 2026 The Bazel Authors. All rights reserved.
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

load("@bazel_features//:features.bzl", "bazel_features")
load("//cc:cc_library.bzl", "cc_library")
load("//cc:cc_shared_library.bzl", "cc_shared_library")
load("//cc:cc_test.bzl", "cc_test")

licenses(["notice"])

VERSION_GATE = [] if bazel_features.cc.cc_common_is_in_rules_cc else ["@platforms//:incompatible"]

cc_library(
    name = "exported_transitive",
    srcs = ["exported_transitive.cc"],
    hdrs = ["exported_transitive.h"],
    local_defines = ["EXPORTED_TRANSITIVE_EXPORTS"],
    target_compatible_with = VERSION_GATE,
)

cc_library(
    name = "exported_transitive_middle",
    srcs = ["exported_transitive_middle.cc"],
    hdrs = ["exported_transitive_middle.h"],
    target_compatible_with = VERSION_GATE,
    deps = [":exported_transitive"],
)

cc_shared_library(
    name = "exports_filter_transitive_so",
    exports_filter = [":exported_transitive"],
    target_compatible_with = VERSION_GATE,
    deps = [":exported_transitive_middle"],
)

cc_library(
    name = "uses_exported_transitive",
    srcs = ["uses_exported_transitive.cc"],
    hdrs = ["uses_exported_transitive.h"],
    local_defines = ["USES_EXPORTED_TRANSITIVE_EXPORTS"],
    target_compatible_with = VERSION_GATE,
    deps = [":exported_transitive"],
)

cc_shared_library(
    name = "uses_exported_transitive_so",
    dynamic_deps = [":exports_filter_transitive_so"],
    target_compatible_with = VERSION_GATE,
    deps = [":uses_exported_transitive"],
)

cc_test(
    name = "exports_filter_transitive_test",
    srcs = ["exports_filter_transitive_test.cc"],
    dynamic_deps = [":uses_exported_transitive_so"],
    target_compatible_with = VERSION_GATE,
)
