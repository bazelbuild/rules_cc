"""Specialized analysis_test and test_suite for rules_cc."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test")

def cc_analysis_test(name, with_features = None, test_features = [], **kwargs):
    """Runs an analysis_test with the a mock C++ toolchain.

    Args:
        name: The name of the test.
        with_features: The toolchain's available features. A test that wants to use a feature
            must enable it by setting the test_features attribute. By default, with_features
            matches test_features. This saves test writers from having to set the same values
            in both. Set with_features explicitly when you want to test mismatches between
            requested features and features the toolchain supports.
        test_features: The features the test wants to enable. This is equivalent to setting
            the `--features` build flag.
        **kwargs: Args passed through to test_suite.
    """

    if with_features == None:
        with_features = test_features

    # Make this a Label to bind it to the rules_cc repo where its BUILD files lives. If we kept it
    # as a string that would bind it to rules_testing where analysis_test lives.
    with_features_flag = Label("//tests/cc/testutil/toolchains:with_features")

    config_settings = {
        "//command_line_option:extra_toolchains": "//tests/cc/testutil/toolchains:cc-toolchain-k8-compiler",
        str(with_features_flag): with_features,
        "//command_line_option:features": test_features,
    }
    if "config_settings" in kwargs:
        config_settings = dict(config_settings, **kwargs["config_settings"])
        kwargs.pop("config_settings")
    analysis_test(
        name = name,
        config_settings = config_settings,
        **kwargs
    )
