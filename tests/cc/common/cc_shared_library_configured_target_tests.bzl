"""Tests for cc_shared_library."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@rules_testing//lib:analysis_test.bzl", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching")
load("@rules_testing//lib:util.bzl", "util")
load("//cc:cc_library.bzl", "cc_library")
load("//cc:cc_shared_library.bzl", "cc_shared_library")
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test")

def _test_runfiles(name, **kwargs):
    util.helper_target(
        cc_shared_library,
        name = name + "/runfiles/0",
        deps = [name + "/runfiles/1"],
    )
    file1 = util.empty_file(name = name + "/runfiles/file1")
    util.helper_target(
        cc_library,
        name = name + "/runfiles/1",
        data = [file1],
    )
    cc_analysis_test(
        name = name,
        impl = _test_runfiles_impl,
        target = name + "/runfiles/0",
        **kwargs
    )

def _test_runfiles_impl(env, target):
    env.expect.that_target(target).data_runfiles().contains_predicate(
        matching.str_endswith("lib0.so"),
    )
    env.expect.that_target(target).data_runfiles().contains_predicate(
        matching.str_endswith("file1"),
    )

def cc_shared_library_configured_target_tests(name):
    test_suite(
        name = name,
        tests = [
            _test_runfiles,
        ] if bazel_features.cc.cc_common_is_in_rules_cc else [],
    )
