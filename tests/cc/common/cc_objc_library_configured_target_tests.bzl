"""Tests for objc_library."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@rules_testing//lib:analysis_test.bzl", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching")
load("@rules_testing//lib:util.bzl", "util")
load("//cc:action_names.bzl", "ACTION_NAMES")
load("//cc:objc_library.bzl", "objc_library")
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test")

def _test_data_in_runfiles(name, **kwargs):
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
    target.data_runfiles().contains_predicate(matching.str_endswith(".a"))

def cc_objc_library_configured_target_tests(name):
    test_suite(
        name = name,
        tests = [
            _test_data_in_runfiles,
        ] if bazel_features.cc.cc_common_is_in_rules_cc else [],
    )
