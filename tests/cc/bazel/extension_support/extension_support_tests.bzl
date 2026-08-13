"""Tests for cc/cc_rules_extension_support.bzl"""

load("@bazel_features//:features.bzl", "bazel_features")
load("@rules_testing//lib:analysis_test.bzl", "test_suite")
load("@rules_testing//lib:util.bzl", "util")
load("//cc:cc_binary.bzl", "cc_binary")
load(
    "//cc:cc_rules_extension_support.bzl",
    _cc_binary_for_ext = "cc_binary",
    _cc_library_for_ext = "cc_library",
)
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test")
load("//tests/cc/testutil:cc_binary_target_subject.bzl", "cc_binary_target_subject")

def _safe_for_bazel7_macro(**kwargs):
    if bazel_features.globals.macro:
        return bazel_features.globals.macro(**kwargs)
    return lambda **kwargs: None

def _safe_for_bazel7_rule(**kwargs):
    if bazel_features.rules.rule_extension_apis_available:
        return rule(**kwargs)
    return lambda **kwargs: None

def _my_cc_binary_macro_impl(**kwargs):
    cc_binary(**kwargs)

_my_cc_binary_macro = _safe_for_bazel7_macro(
    implementation = _my_cc_binary_macro_impl,
    inherit_attrs = _cc_binary_for_ext,
)

def _my_cc_library_rule_impl(ctx):
    return ctx.super()

_my_cc_library_rule = _safe_for_bazel7_rule(
    implementation = _my_cc_library_rule_impl,
    parent = _cc_library_for_ext,
)

def _test_cc_binary_macro(name):
    util.helper_target(
        _my_cc_binary_macro,
        name = name + "_wrapped",
        srcs = ["foo.cc"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_cc_binary_macro_impl,
        target = name + "_wrapped",
    )

def _test_cc_binary_macro_impl(env, target):
    cc_binary_target_subject.from_target(env, target).executable().short_path_equals(
        "{package}/{name}{binary_extension}",
    )

def _test_cc_library_extension(name):
    util.helper_target(
        _my_cc_library_rule,
        name = name + "_lib",
        srcs = ["foo.cc"],
        hdrs = ["foo.h"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_cc_library_extension_impl,
        target = name + "_lib",
    )

def _test_cc_library_extension_impl(env, target):
    env.expect.that_target(target).default_outputs().contains_exactly([
        "{package}/lib{name}.a",
    ])

def extension_support_tests(name):
    test_suite(
        name = name,
        tests = [
            _test_cc_binary_macro,
            _test_cc_library_extension,
        ],
    )
