"""Tests for disallowed copts enforcement outside allowlist."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@rules_testing//lib:analysis_test.bzl", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching")
load("@rules_testing//lib:util.bzl", "util")
load("//cc:cc_binary.bzl", "cc_binary")
load("//cc:cc_library.bzl", "cc_library")
load("//tests/cc/testutil:cc_analysis_test.bzl", "MOCK_ALLOWLIST_TOOLCHAINS", "MOCK_EMPTY_ALLOWLIST_TOOLCHAINS", "cc_analysis_test")

def _test_pass_impl(_env, _target):
    pass

def _test_fail_impl(env, target):
    env.expect.that_target(target).failures().contains_predicate(
        matching.contains("[DISALLOWED COPTS ERROR]"),
    )

def _test_fail_empty_toolchain_allowlist_impl(env, target):
    env.expect.that_target(target).failures().contains_predicate(
        matching.contains(
            "- Flag '-Wno-error' (target is not in the allowlist '//custom:toolchain_allowlist'): Custom warning policy guidance.",
        ),
    )

def _test_disallowed_copt_fails(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/test",
        copts = ["-Wno-error"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_fail_impl,
        target = name + "/test",
        expect_failure = True,
        **kwargs
    )

def _test_disallowed_copt_in_toolchain_allowlist_passes(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/test",
        copts = ["-Wno-error"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_pass_impl,
        target = name + "/test",
        config_settings = {
            "//command_line_option:extra_toolchains": ",".join(MOCK_ALLOWLIST_TOOLCHAINS),
        },
        **kwargs
    )

def _test_disallowed_copt_cc_binary_in_toolchain_allowlist_passes(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/test",
        copts = ["-Wno-error"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_pass_impl,
        target = name + "/test",
        config_settings = {
            "//command_line_option:extra_toolchains": ",".join(MOCK_ALLOWLIST_TOOLCHAINS),
        },
        **kwargs
    )

def _test_disallowed_copt_with_empty_toolchain_allowlist_fails(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/test",
        copts = ["-Wno-error"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_fail_empty_toolchain_allowlist_impl,
        target = name + "/test",
        expect_failure = True,
        config_settings = {
            "//command_line_option:extra_toolchains": ",".join(MOCK_EMPTY_ALLOWLIST_TOOLCHAINS),
        },
        **kwargs
    )

def _test_valid_warning_passes(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/test",
        copts = ["-Wall"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_pass_impl,
        target = name + "/test",
        **kwargs
    )

def _test_no_copts_target_passes(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/test",
    )
    cc_analysis_test(
        name = name,
        impl = _test_pass_impl,
        target = name + "/test",
        **kwargs
    )

def disallowed_copts_tests(name):
    test_suite(
        name = name,
        tests = [
            _test_disallowed_copt_fails,
            _test_disallowed_copt_in_toolchain_allowlist_passes,
            _test_disallowed_copt_cc_binary_in_toolchain_allowlist_passes,
            _test_disallowed_copt_with_empty_toolchain_allowlist_fails,
            _test_valid_warning_passes,
            _test_no_copts_target_passes,
        ] if bazel_features.cc.cc_common_is_in_rules_cc else [],
    )
