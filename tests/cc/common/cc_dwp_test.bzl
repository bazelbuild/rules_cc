"""Tests for DWP action environment variables."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@rules_testing//lib:analysis_test.bzl", "test_suite")
load("@rules_testing//lib:util.bzl", "TestingAspectInfo", "util")
load("//cc:action_names.bzl", "ACTION_NAMES")
load("//cc:cc_binary.bzl", "cc_binary")
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test")
load("//tests/cc/testutil/toolchains:features.bzl", "FEATURE_NAMES")

_DWP_TEST_FEATURES = [
    FEATURE_NAMES.per_object_debug_info,
    FEATURE_NAMES.dwp_env,
]

_DWP_ACTION_CONFIGS = [
    ACTION_NAMES.cpp_compile,
    ACTION_NAMES.cpp_link_executable,
    ACTION_NAMES.cpp_link_static_library,
    ACTION_NAMES.dwp,
]

_DWP_CONFIG_SETTINGS = {
    "//command_line_option:fission": "yes",
}

def _assert_dwp_env(env, target, expected_mnemonics):
    dwp_actions = {}
    for action in target[TestingAspectInfo].actions:
        if action.mnemonic in ("CcGenerateDwp", "CcGenerateIntermediateDwp"):
            dwp_actions[action.mnemonic] = action

    env.expect.that_collection(dwp_actions.keys()).contains_at_least(expected_mnemonics)
    for mnemonic, action in dwp_actions.items():
        env.expect.where(
            detail = "mnemonic: %s" % mnemonic,
        ).that_dict(action.env).contains_at_least({"DWP_ENV_KEY": "DWP_ENV_VALUE"})

        env.expect.where(
            detail = "mnemonic: %s" % mnemonic,
        ).that_dict(action.env).keys().contains("PATH")

def _test_dwp_env(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/hello",
        srcs = ["hello.cc"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_dwp_env_impl,
        target = name + "/hello",
        test_features = _DWP_TEST_FEATURES,
        with_action_configs = _DWP_ACTION_CONFIGS,
        config_settings = _DWP_CONFIG_SETTINGS,
        **kwargs
    )

def _test_dwp_env_impl(env, target):
    _assert_dwp_env(env, target, ["CcGenerateDwp"])

def _test_intermediate_dwp_env(name, **kwargs):
    # Generate 101 source files to exceed the batch size,
    # triggering CcGenerateIntermediateDwp actions.
    srcs = []
    for i in range(101):
        src = name + "/src_%d.cc" % i
        native.genrule(
            name = src.replace("/", "_").replace(".", "_"),
            outs = [src],
            cmd = "echo 'void f_%d() {}' > $@" % i,
        )
        srcs.append(src)

    util.helper_target(
        cc_binary,
        name = name + "/many_srcs",
        srcs = srcs,
    )
    cc_analysis_test(
        name = name,
        impl = _test_intermediate_dwp_env_impl,
        target = name + "/many_srcs",
        test_features = _DWP_TEST_FEATURES,
        with_action_configs = _DWP_ACTION_CONFIGS,
        config_settings = _DWP_CONFIG_SETTINGS,
        **kwargs
    )

def _test_intermediate_dwp_env_impl(env, target):
    _assert_dwp_env(env, target, ["CcGenerateDwp", "CcGenerateIntermediateDwp"])

def cc_dwp_tests(name):
    tests = []
    if bazel_features.cc.cc_common_is_in_rules_cc:
        tests = [
            _test_dwp_env,
            _test_intermediate_dwp_env,
        ]
    test_suite(
        name = name,
        tests = tests,
    )
