"""Tests for C++ modules."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@rules_testing//lib:analysis_test.bzl", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching")
load("@rules_testing//lib:util.bzl", "util")
load("//cc:cc_binary.bzl", "cc_binary")
load("//cc:cc_library.bzl", "cc_library")
load("//cc:cc_test.bzl", "cc_test")
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test")

def _test_cpp_modules_cc_library_configuration_no_flags(name):
    util.empty_file(name + "/foo.cppm")
    util.helper_target(
        cc_library,
        name = name + "_lib",
        module_interfaces = [name + "/foo.cppm"],
    )
    cc_analysis_test(
        name = name,
        target = name + "_lib",
        impl = _test_cpp_modules_no_flags_impl,
        expect_failure = True,
    )

def _test_cpp_modules_cc_binary_configuration_no_flags(name):
    util.empty_file(name + "/foo.cppm")
    util.helper_target(
        cc_binary,
        name = name + "_bin",
        module_interfaces = [name + "/foo.cppm"],
    )
    cc_analysis_test(
        name = name,
        target = name + "_bin",
        impl = _test_cpp_modules_no_flags_impl,
        expect_failure = True,
    )

def _test_cpp_modules_cc_test_configuration_no_flags(name):
    util.empty_file(name + "/foo.cppm")
    util.helper_target(
        cc_test,
        name = name + "_test",
        module_interfaces = [name + "/foo.cppm"],
    )
    cc_analysis_test(
        name = name,
        target = name + "_test",
        impl = _test_cpp_modules_no_flags_impl,
        expect_failure = True,
    )

def _test_cpp_modules_no_flags_impl(env, target):
    env.expect.that_target(target).failures().contains_predicate(
        matching.contains("requires --experimental_cpp_modules"),
    )

def _test_cpp_modules_cc_library_configuration_no_features(name):
    util.empty_file(name + "/foo.cppm")
    util.helper_target(
        cc_library,
        name = name + "_lib",
        module_interfaces = [name + "/foo.cppm"],
    )
    cc_analysis_test(
        name = name,
        target = name + "_lib",
        impl = _test_cpp_modules_no_features_impl,
        expect_failure = True,
        config_settings = {
            "//command_line_option:experimental_cpp_modules": True,
        },
    )

def _test_cpp_modules_cc_binary_configuration_no_features(name):
    util.empty_file(name + "/foo.cppm")
    util.helper_target(
        cc_binary,
        name = name + "_bin",
        module_interfaces = [name + "/foo.cppm"],
    )
    cc_analysis_test(
        name = name,
        target = name + "_bin",
        impl = _test_cpp_modules_no_features_impl,
        expect_failure = True,
        config_settings = {
            "//command_line_option:experimental_cpp_modules": True,
        },
    )

def _test_cpp_modules_cc_test_configuration_no_features(name):
    util.empty_file(name + "/foo.cppm")
    util.helper_target(
        cc_test,
        name = name + "_test",
        module_interfaces = [name + "/foo.cppm"],
    )
    cc_analysis_test(
        name = name,
        target = name + "_test",
        impl = _test_cpp_modules_no_features_impl,
        expect_failure = True,
        config_settings = {
            "//command_line_option:experimental_cpp_modules": True,
        },
    )

def _test_cpp_modules_no_features_impl(env, target):
    failures = env.expect.that_target(target).failures()
    failures.contains_predicate(
        matching.contains("the feature cpp_modules must be enabled"),
    )
    failures.not_contains_predicate(
        matching.contains("requires --experimental_cpp_modules"),
    )

def cpp_modules_tests(name):
    tests = []
    if bazel_features.cc.cc_common_is_in_rules_cc:
        tests.extend([
            _test_cpp_modules_cc_library_configuration_no_flags,
            _test_cpp_modules_cc_binary_configuration_no_flags,
            _test_cpp_modules_cc_test_configuration_no_flags,
            _test_cpp_modules_cc_library_configuration_no_features,
            _test_cpp_modules_cc_binary_configuration_no_features,
            _test_cpp_modules_cc_test_configuration_no_features,
        ])

    test_suite(
        name = name,
        tests = tests,
    )
