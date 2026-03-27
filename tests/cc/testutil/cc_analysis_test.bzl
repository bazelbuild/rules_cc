"""Specialized analysis_test and test_suite for rules_cc."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("//tests/cc/testutil/toolchains:additional_toolchains.bzl", "ADDITIONAL_MOCK_TOOLCHAINS")

def cc_analysis_test(name, with_features = None, test_features = [], with_action_configs = [], **kwargs):
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
        with_action_configs: The toolchain's available action configs.
        **kwargs: Args passed through to test_suite.
    """

    if with_features == None:
        with_features = test_features

    # Mock these as Labels to bind to the rules_cc repo where the BUILD file lives. If we kept them
    # as strings, they'd get bound to rules_testing where analysis_test lives.
    #
    # That's becuase these get passed as strings to analysis_test's config_settings parameter, which
    # is passed into the native function analysis_test_transition at
    # https://github.com/bazelbuild/rules_testing/blob/a8db9af940e51ea80a48836c49fea4d6a3660a2e/lib/private/analysis_test.bzl#L259-L261.
    # That native code binds "//"-style labels to its calling context which is in rules_testing.

    with_features_flag = Label("//tests/cc/testutil/toolchains:with_features")
    with_action_configs_flag = Label("//tests/cc/testutil/toolchains:with_action_configs")

    mock_toolchains = [
        "//tests/cc/testutil/toolchains:cc-toolchain-k8-compiler",
        "//tests/cc/testutil/toolchains:cc-toolchain-macos-compiler",
    ] + ADDITIONAL_MOCK_TOOLCHAINS

    config_settings = {
        "//command_line_option:extra_toolchains": ",".join(mock_toolchains),
        str(with_features_flag): with_features,
        str(with_action_configs_flag): with_action_configs,
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
