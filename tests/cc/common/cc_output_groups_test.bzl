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

"""Tests for the output groups of cc_library."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@rules_testing//lib:analysis_test.bzl", "test_suite")
load("@rules_testing//lib:util.bzl", "util")
load("//cc:cc_binary.bzl", "cc_binary")
load("//cc:cc_library.bzl", "cc_library")
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test")

def _test_static_library_only_output_groups(name, **kwargs):
    util.helper_target(
        name = name + "/lib",
        rule = cc_library,
        srcs = ["src.cc"],
        linkstatic = 1,
        alwayslink = 0,
    )

    cc_analysis_test(
        name = name,
        impl = _test_static_library_only_output_groups_impl,
        test_features = ["supports_dynamic_linker"],
        target = name + "/lib",
        **kwargs
    )

def _test_static_library_only_output_groups_impl(env, target):
    assert_target = env.expect.that_target(target)
    assert_target.output_group("archive").contains_exactly([
        "{package}/{test_name}/liblib.a",
    ])
    assert_target.output_group("dynamic_library").is_empty()

def _test_shared_library_only_output_groups(name, **kwargs):
    util.helper_target(
        name = name + "/lib",
        rule = cc_library,
        srcs = ["src.cc"],
        linkstatic = 1,
        alwayslink = 1,
    )

    cc_analysis_test(
        name = name,
        impl = _test_shared_library_only_output_groups_impl,
        test_features = ["supports_dynamic_linker"],
        target = name + "/lib",
        **kwargs
    )

def _test_shared_library_only_output_groups_impl(env, target):
    assert_target = env.expect.that_target(target)
    assert_target.output_group("archive").contains_exactly([
        "{package}/{test_name}/liblib.lo",
    ])
    assert_target.output_group("dynamic_library").is_empty()

def _test_static_and_dynamic_library_output_groups(name, **kwargs):
    util.helper_target(
        name = name + "/lib",
        rule = cc_library,
        srcs = ["src.cc"],
        linkstatic = 0,
        alwayslink = 0,
    )

    cc_analysis_test(
        name = name,
        impl = _test_static_and_dynamic_library_output_groups_impl,
        test_features = ["supports_dynamic_linker"],
        target = name + "/lib",
        **kwargs
    )

def _test_static_and_dynamic_library_output_groups_impl(env, target):
    assert_target = env.expect.that_target(target)
    assert_target.output_group("archive").contains_exactly([
        "{package}/{test_name}/liblib.a",
    ])
    assert_target.output_group("dynamic_library").contains_exactly([
        "{package}/{test_name}/liblib.so",
    ])

def _test_shared_and_dynamic_library_output_groups(name, **kwargs):
    util.helper_target(
        name = name + "/lib",
        rule = cc_library,
        srcs = ["src.cc"],
        linkstatic = 0,
        alwayslink = 1,
    )

    cc_analysis_test(
        name = name,
        impl = _test_shared_and_dynamic_library_output_groups_impl,
        test_features = ["supports_dynamic_linker"],
        target = name + "/lib",
        **kwargs
    )

def _test_shared_and_dynamic_library_output_groups_impl(env, target):
    assert_target = env.expect.that_target(target)
    assert_target.output_group("archive").contains_exactly([
        "{package}/{test_name}/liblib.lo",
    ])
    assert_target.output_group("dynamic_library").contains_exactly([
        "{package}/{test_name}/liblib.so",
    ])

def _test_module_output_groups(name, **kwargs):
    util.helper_target(
        rule = cc_library,
        name = name + "/lib",
        hdrs = ["src.h"],
        features = ["header_modules"],
    )

    cc_analysis_test(
        name = name,
        target = name + "/lib",
        test_features = ["header_modules_feature_configuration"],
        impl = _test_module_output_groups_impl,
        **kwargs
    )

def _test_module_output_groups_impl(env, target):
    env.expect.that_target(target).output_group("module_files").contains_exactly([
        "{package}/_objs/{test_name}/lib/lib.pcm",
    ])

def _test_compilation_outputs_group(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/foo",
        srcs = [
            "foo.cc",
            name + "/gen",
        ],
        deps = [name + "/bar"],
    )

    util.helper_target(
        cc_library,
        name = name + "/bar",
        srcs = ["bar.cc"],
    )

    util.helper_target(
        native.genrule,
        name = name + "/gen",
        outs = [
            name + "/gen.cc",
            name + "/gen.h",
        ],
        cmd = "touch $(OUTS)",
    )

    cc_analysis_test(
        name = name,
        impl = _test_compilation_outputs_group_impl,
        target = name + "/foo",
        test_features = [
            "supports_pic",
        ],
        **kwargs
    )

def _test_compilation_outputs_group_impl(env, target):
    # Artifacts from deps and the final linking output should not be in this group
    # Only the direct compilation outputs should be present.
    env.expect.that_target(target).output_group("compilation_outputs").contains_exactly([
        "{package}/_objs/{test_name}/foo/foo.pic.o",
        "{package}/_objs/{test_name}/foo/gen.pic.o",
    ])

def cc_output_groups_tests(name):
    tests = []
    if bazel_features.cc.cc_common_is_in_rules_cc:
        tests = [
            _test_static_library_only_output_groups,
            _test_shared_library_only_output_groups,
            _test_static_and_dynamic_library_output_groups,
            _test_shared_and_dynamic_library_output_groups,
            _test_module_output_groups,
            _test_compilation_outputs_group,
        ]

    test_suite(
        name = name,
        tests = tests,
    )
