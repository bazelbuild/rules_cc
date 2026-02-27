"""Tests for cc_binary."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test", "test_suite")
load("@rules_testing//lib:util.bzl", "util")
load("//cc:cc_binary.bzl", "cc_binary")

def _test_files_to_build(name):
    util.helper_target(
        cc_binary,
        name = name + "/hello",
        srcs = ["hello.cc"],
    )
    analysis_test(
        name = name,
        impl = _test_files_to_build_impl,
        target = name + "/hello",
    )

def _test_files_to_build_impl(env, target):
    env.expect.that_target(target).default_outputs().contains_exactly(["{package}/{name}"])
    env.expect.that_target(target).executable().short_path_equals("{package}/{name}")

def cc_binary_configured_target_tests(name):
    test_suite(
        name = name,
        tests = [
            _test_files_to_build,
        ],
    )
