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

load("//cc:cc_library.bzl", "cc_library")
load("//cc:cc_test.bzl", "cc_test")

licenses(["notice"])

# Fixture for .bazelci/verify_coverage.sh, which asserts after every
# `bazel coverage` run in CI that executed lines were recorded for lib.c.
# It exists so the check does not depend on whichever other tests happen to
# be instrumented, and it must therefore stay buildable on every Bazel version
# and platform CI covers: plain C, no version gate, no third-party
# dependencies.
#
# Bazel never instruments a test's own sources (`--instrument_test_targets`
# defaults to false), so the code under measurement lives in a library that
# the test exercises.
cc_library(
    name = "lib",
    srcs = ["lib.c"],
    hdrs = ["lib.h"],
)

cc_test(
    name = "coverage_test",
    srcs = ["coverage_test.c"],
    deps = [":lib"],
)
