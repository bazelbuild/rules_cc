"""Tests for cc_common APIs"""

load("@rules_testing//lib:analysis_test.bzl", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching")
load("@rules_testing//lib:util.bzl", "util")
load("//cc:cc_library.bzl", "cc_library")
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test")

def _test_same_cc_file_twice(name):
    util.helper_target(
        native.filegroup,
        name = name + "/a1",
        srcs = ["a.cc"],
    )
    util.helper_target(
        native.filegroup,
        name = name + "/a2",
        srcs = ["a.cc"],
    )
    util.helper_target(
        cc_library,
        name = name + "/a",
        srcs = [
            name + "/a1",
            name + "/a2",
        ],
    )

    cc_analysis_test(
        name = name,
        impl = _test_same_cc_file_twice_impl,
        target = name + "/a",
        expect_failure = True,
    )

def _test_same_cc_file_twice_impl(env, target):
    expected_msg = "Artifact '{package}/a.cc' is duplicated".format(package = target.label.package)
    env.expect.that_target(target).failures().contains_predicate(
        matching.custom(
            "contains '{}'".format(expected_msg),
            lambda s: expected_msg in s,
        ),
    )

def _test_same_header_file_twice(name):
    util.helper_target(
        native.filegroup,
        name = name + "/a1",
        srcs = ["a.h"],
    )
    util.helper_target(
        native.filegroup,
        name = name + "/a2",
        srcs = ["a.h"],
    )
    util.helper_target(
        cc_library,
        name = name + "/a",
        srcs = [
            "a.cc",
            name + "/a1",
            name + "/a2",
        ],
        features = ["parse_headers"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_same_header_file_twice_impl,
        target = name + "/a",
    )

def _test_same_header_file_twice_impl(env, target):
    env.expect.that_target(target).failures().contains_exactly([])

def cc_common_tests(name):
    test_suite(
        name = name,
        tests = [
            _test_same_cc_file_twice,
            _test_same_header_file_twice,
        ],
    )
