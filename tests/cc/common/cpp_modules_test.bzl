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

def _generated_module_map_headers_impl(ctx):
    headers = ctx.actions.declare_directory(ctx.label.name + ".h")
    ctx.actions.run_shell(
        outputs = [headers],
        arguments = [headers.path],
        command = "mkdir -p \"$1\" && touch \"$1/generated.h\"",
    )
    return [DefaultInfo(files = depset([headers]))]

_generated_module_map_headers = rule(implementation = _generated_module_map_headers_impl)

def _test_module_map_action_with_tree_artifact_headers(name):
    util.empty_file(name + "/public.h")
    util.empty_file(name + "/private.h")
    util.empty_file(name + "/textual.h")
    util.helper_target(
        _generated_module_map_headers,
        name = name + "_generated_headers",
    )
    util.helper_target(
        cc_library,
        name = name + "_lib",
        srcs = [name + "/private.h"],
        hdrs = [
            name + "/public.h",
            name + "_generated_headers",
        ],
        textual_hdrs = [name + "/textual.h"],
    )
    cc_analysis_test(
        name = name,
        target = name + "_lib",
        impl = _test_module_map_action_with_tree_artifact_headers_impl,
        test_features = ["module_maps"],
    )

def _test_module_map_action_with_tree_artifact_headers_impl(env, target):
    generated_headers = "{}/{}_generated_headers.h".format(
        target.label.package,
        env.ctx.label.name,
    )
    env.expect.that_target(target).action_named("CppModuleMap").inputs().contains(
        generated_headers,
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
            _test_module_map_action_with_tree_artifact_headers,
        ])

    test_suite(
        name = name,
        tests = tests,
    )
