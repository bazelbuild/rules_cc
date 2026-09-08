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

"""Tests for Clang header modules."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@rules_testing//lib:analysis_test.bzl", "test_suite")
load("@rules_testing//lib:util.bzl", "util")
load("//cc:cc_library.bzl", "cc_library")
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test")

_HEADER_MODULE_FEATURES = [
    "header_modules",
    "use_header_modules",
    "header_module_codegen",
]

def _test_module_codegen_action_inputs(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/a",
        hdrs = ["a.h"],
        features = _HEADER_MODULE_FEATURES,
    )
    util.helper_target(
        cc_library,
        name = name + "/b",
        hdrs = ["b.h"],
        deps = [name + "/a"],
        features = _HEADER_MODULE_FEATURES,
    )

    cc_analysis_test(
        name = name,
        target = name + "/b",
        test_features = ["header_modules_feature_configuration"],
        impl = _test_module_codegen_action_inputs_impl,
        **kwargs
    )

def _test_module_codegen_action_inputs_impl(env, target):
    # Compiling b's module file into an object file loads it, which in turn loads the module files
    # it imports, so those are inputs even though the codegen action's source isn't itself compiled
    # with header modules.
    codegen_action = env.expect.that_target(target).action_generating(
        "{package}/_objs/{test_name}/b/b.pcm.o",
    )
    codegen_action.inputs().contains("{package}/_objs/{test_name}/a/a.pcm")

def header_modules_tests(name):
    tests = []
    if bazel_features.cc.cc_common_is_in_rules_cc:
        tests = [
            _test_module_codegen_action_inputs,
        ]

    test_suite(
        name = name,
        tests = tests,
    )
