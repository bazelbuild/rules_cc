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
load("//cc:cc_test.bzl", "cc_test")

licenses(["notice"])

VERSION_GATE = [] if bazel_features.cc.cc_common_is_in_rules_cc else ["@platforms//:incompatible"]

# Library that provides the registration state (was_registered/set_registered).
cc_library(
    name = "registered",
    srcs = ["registered.c"],
    hdrs = ["registered.h"],
)

# Library that registers itself via a static constructor.
cc_library(
    name = "registerer_lib",
    srcs = ["registerer.c"],
    features = ["-supports_start_end_lib"],
    deps = [":registered"],
)

# Copy the static archive produced by registerer_lib, simulates having a prebuilt archive.
genrule(
    name = "copy_registerer_archive_unix",
    srcs = [":registerer_lib"],
    outs = ["libregisterer_copied.a"],
    cmd = "for f in $(locations :registerer_lib); do case \"$$f\" in *.a) cp \"$$f\" $@;; esac; done",
    target_compatible_with = select({
        "@platforms//os:windows": ["@platforms//:incompatible"],
        "//conditions:default": [],
    }),
)

genrule(
    name = "copy_registerer_archive_windows",
    srcs = [":registerer_lib"],
    outs = ["registerer_copied.lib"],
    cmd = "for f in $(locations :registerer_lib); do case \"$$f\" in *.lib) cp \"$$f\" $@;; esac; done",
    target_compatible_with = ["@platforms//os:windows"],
)

# Library that uses the copied archive in srcs with alwayslink=True.
# Without alwayslink, the registerer would be dropped since nothing
# directly references its symbols.
cc_library(
    name = "registerer_alwayslink",
    srcs = select({
        "@platforms//os:windows": [":copy_registerer_archive_windows"],
        "//conditions:default": [":copy_registerer_archive_unix"],
    }),
    target_compatible_with = VERSION_GATE,
    deps = [":registered"],
    alwayslink = True,
)

# Test that verifies the symbol was loaded at runtime.
# The test does not directly reference any symbol from registerer,
# so without alwayslink the static constructor would not run.
cc_test(
    name = "alwayslink_test",
    srcs = ["alwayslink_test.c"],
    deps = [
        ":registered",
        ":registerer_alwayslink",
    ],
)
