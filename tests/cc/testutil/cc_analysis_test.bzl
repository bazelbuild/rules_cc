"""Specialized analysis_test and test_suite for rules_cc."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test")

def cc_analysis_test(name, **kwargs):
    """Runs an analysis_test with the a mock C++ toolchain.

    Args:
        name: The name of the test.
        **kwargs: Args passed through to test_suite
    """
    config_settings = {
        "//command_line_option:extra_toolchains": "//tests/cc/testutil/toolchains:cc-toolchain-k8-compiler",
    }
    if "config_settings" in kwargs:
        config_settings = dict(config_settings, **kwargs["config_settings"])
        kwargs.pop("config_settings")
    analysis_test(
        name = name,
        config_settings = config_settings,
        **kwargs
    )
