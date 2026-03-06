"""Specialized analysis_test and test_suite for rules_cc."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test", "test_suite")

def cc_analysis_test(name, *, is_windows, **kwargs):
    analysis_test(
        name = name,
        attrs = {
            "is_windows": attr.bool(),
        },
        attr_values = {
            "is_windows": is_windows,
        },
        **kwargs
    )

def cc_test_suite(name, *, tests = [], basic_tests = [], test_kwargs = {}):
    test_kwargs = dict(test_kwargs, **{
        "is_windows": select({
            "@platforms//os:windows": True,
            "//conditions:default": False,
        }),
    })
    test_suite(
        name = name,
        tests = tests,
        basic_tests = basic_tests,
        test_kwargs = test_kwargs,
    )
