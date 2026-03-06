"""Tests for cc_binary."""

load("@rules_testing//lib:truth.bzl", "matching")
load("@rules_testing//lib:util.bzl", "util")
load("//cc:cc_binary.bzl", "cc_binary")
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test", "cc_test_suite")
load("//tests/cc/testutil:cc_binary_target_subject.bzl", "cc_binary_target_subject")
load("//tests/cc/testutil:link_action_subject.bzl", "link_action_subject")

def _test_files_to_build(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/hello",
        srcs = ["hello.cc"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_files_to_build_impl,
        target = name + "/hello",
        **kwargs
    )

def _test_files_to_build_impl(env, target):
    cc_binary_subject = cc_binary_target_subject.from_target(env, target)
    cc_binary_subject.default_outputs().contains_exactly(["{package}/{name}{binary_extension}"])
    cc_binary_subject.executable().short_path_equals("{package}/{name}{binary_extension}")

def _test_headers_not_passed_to_linking_action(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/bye",
        srcs = ["bye.cc", "bye.h"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_headers_not_passed_to_linking_action_impl,
        target = name + "/bye",
        config_settings = {
            "//command_line_option:features": ["parse_headers"],
            "//command_line_option:process_headers_in_dependencies": True,
        },
        **kwargs
    )

def _test_headers_not_passed_to_linking_action_impl(env, target):
    link_action_subject.from_target(env, target).inputs().contains_none_of([
        matching.str_endswith(".h"),
        matching.str_endswith(".hpp"),
        matching.str_endswith(".hxx"),
    ])

def cc_binary_configured_target_tests(name):
    cc_test_suite(
        name = name,
        tests = [
            _test_files_to_build,
            _test_headers_not_passed_to_linking_action,
        ],
    )
