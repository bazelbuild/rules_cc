"""Tests for cc_import."""

load("@rules_testing//lib:truth.bzl", "matching")
load("@rules_testing//lib:util.bzl", "util")
load("//cc:cc_import.bzl", "cc_import")
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test", "cc_test_suite")

def _test_data_in_runfiles(name, **kwargs):
    util.helper_target(
        cc_import,
        name = name + "/import_with_data",
        hdrs = ["header.h"],
        data = ["data_file.txt"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_data_in_runfiles_impl,
        target = name + "/import_with_data",
        **kwargs
    )

def _test_data_in_runfiles_impl(env, target):
    target = env.expect.that_target(target)
    target.runfiles().contains_predicate(matching.str_endswith("/data_file.txt"))
    target.data_runfiles().contains_predicate(matching.str_endswith("/data_file.txt"))

def cc_import_configured_target_tests(name):
    cc_test_suite(
        name = name,
        tests = [
            _test_data_in_runfiles,
        ],
    )
