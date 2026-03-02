"""Tests for cc_binary."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test", "test_suite")
load("@rules_testing//lib:util.bzl", "util")
load("//cc:cc_binary.bzl", "cc_binary")

def _test_files_to_build(name, binary_extension):
    util.helper_target(
        cc_binary,
        name = name + "/hello",
        srcs = ["hello.cc"],
    )
    analysis_test(
        name = name,
        impl = _test_files_to_build_impl,
        attrs = {
            "binary_extension": attr.string(),
        },
        attr_values = {
            "binary_extension": binary_extension,
        },
        target = name + "/hello",
    )

def _test_files_to_build_impl(env, target):
    expected_extension = env.ctx.attr.binary_extension
    expected_name = "{package}/{name}".format(
        package = target.label.package,
        name = target.label.name,
    ) + expected_extension
    env.expect.that_target(target).default_outputs().contains_exactly([expected_name])
    env.expect.that_target(target).executable().short_path_equals(expected_name)

def cc_binary_configured_target_tests(name):
    test_suite(
        name = name,
        tests = [
            _test_files_to_build,
        ],
        test_kwargs = {
            "binary_extension": select({
                "@platforms//os:windows": ".exe",
                "//conditions:default": "",
            }),
        },
    )
