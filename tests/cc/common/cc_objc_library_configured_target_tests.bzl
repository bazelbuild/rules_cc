"""Tests for objc_library."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@rules_testing//lib:analysis_test.bzl", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching")
load("@rules_testing//lib:util.bzl", "util")
load("//cc:action_names.bzl", "ACTION_NAMES")
load("//cc:objc_library.bzl", "objc_library")
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test")

def _test_objc_data_in_runfiles(name, **kwargs):
    util.helper_target(
        objc_library,
        name = name + "_lib_with_data",
        srcs = ["source.m"],
        hdrs = ["header.h"],
        data = ["data_file.txt"],
        target_compatible_with = ["@platforms//os:macos"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_data_in_runfiles_impl,
        target = name + "_lib_with_data",
        with_action_configs = [ACTION_NAMES.objc_compile],
        **kwargs
    )

def _test_data_in_runfiles_impl(env, target):
    target = env.expect.that_target(target)
    target.runfiles().contains_predicate(matching.str_endswith("/data_file.txt"))
    target.data_runfiles().contains_predicate(matching.str_endswith("/data_file.txt"))
    target.runfiles().not_contains_predicate(matching.str_endswith(".a"))
    target.data_runfiles().not_contains_predicate(matching.str_endswith(".a"))

def _test_arc_output_directories(name, **kwargs):
    util.helper_target(
        objc_library,
        name = name + "_lib",
        srcs = ["arc_source.m"],
        non_arc_srcs = ["non_arc_source.m"],
        target_compatible_with = ["@platforms//os:macos"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_arc_output_directories_impl,
        target = name + "_lib",
        with_action_configs = [ACTION_NAMES.objc_compile],
        **kwargs
    )

def _test_arc_output_directories_impl(env, target):
    outputs = [file.short_path for file in target[OutputGroupInfo].compilation_outputs.to_list()]
    env.expect.that_collection(outputs).contains_predicate(matching.custom(
        "contains '/arc/'",
        lambda output: "/arc/" in output,
    ))
    env.expect.that_collection(outputs).contains_predicate(matching.custom(
        "contains '/non_arc/'",
        lambda output: "/non_arc/" in output,
    ))

def cc_objc_library_configured_target_tests(name):
    test_suite(
        name = name,
        tests = [
            _test_arc_output_directories,
            _test_objc_data_in_runfiles,
        ] if bazel_features.cc.cc_common_is_in_rules_cc else [],
    )
