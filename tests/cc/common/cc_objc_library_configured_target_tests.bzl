"""Tests for objc_library."""

load("@bazel_features//private:util.bzl", _bazel_version_ge = "ge")
load("@rules_testing//lib:truth.bzl", "matching")
load("@rules_testing//lib:util.bzl", "util")
load("//cc:objc_library.bzl", "objc_library")
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test", "cc_test_suite")

_use_rules_cc_impls = _bazel_version_ge("9.0.0-pre.20250911")

def _test_data_in_runfiles(name, **kwargs):
    util.helper_target(
        objc_library,
        name = name + "_lib_with_data",
        hdrs = ["header.h"],
        data = ["data_file.txt"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_data_in_runfiles_impl,
        target = name + "_lib_with_data",
        **kwargs
    )

def _test_data_in_runfiles_impl(env, target):
    target = env.expect.that_target(target)
    target.runfiles().contains_predicate(matching.str_endswith("/data_file.txt"))
    target.data_runfiles().contains_predicate(matching.str_endswith("/data_file.txt"))

def cc_objc_library_configured_target_tests(name):
    cc_test_suite(
        name = name,
        tests = [
            _test_data_in_runfiles,
        ] if _use_rules_cc_impls else [],
    )
