"""Tests for FDO action environment variables."""

load("@bazel_features//private:util.bzl", _bazel_version_ge = "ge")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test", "test_suite")
load("@rules_testing//lib:util.bzl", "TestingAspectInfo")
load("//cc:action_names.bzl", "ACTION_NAMES")
load("//cc/toolchains:fdo_profile.bzl", "fdo_profile")
load("//tests/cc/testutil/toolchains:features.bzl", "FEATURE_NAMES")

def _test_fdo_profdata_env(name, **kwargs):
    native.genrule(
        name = name + "_profraw",
        outs = [name + "/profile.profraw"],
        cmd = "touch $@",
    )

    fdo_profile(
        name = name + "_profile",
        profile = name + "_profraw",
    )

    analysis_test(
        name = name,
        impl = _test_fdo_profdata_env_impl,
        target = "//tests/cc/testutil/toolchains:cc-compiler-k8-compiler",
        config_settings = _fdo_config_settings(name),
        **kwargs
    )

def _fdo_config_settings(name):
    return {
        str(Label("//tests/cc/testutil/toolchains:with_features")): [
            FEATURE_NAMES.fdo_optimize,
            FEATURE_NAMES.llvm_profdata_env,
        ],
        str(Label("//tests/cc/testutil/toolchains:with_action_configs")): [
            ACTION_NAMES.llvm_profdata,
        ],
        "//command_line_option:fdo_optimize": "//tests/cc/common:" + name + "_profile",
        "//command_line_option:compilation_mode": "opt",
    }

def _assert_profdata_env(env, target, expected_mnemonics):
    profdata_actions = []
    seen_mnemonics = {}
    for action in target[TestingAspectInfo].actions:
        if action.mnemonic in expected_mnemonics:
            profdata_actions.append(action)
            seen_mnemonics[action.mnemonic] = True

    env.expect.that_collection(seen_mnemonics.keys()).contains_at_least(expected_mnemonics)
    for action in profdata_actions:
        env.expect.where(
            detail = "mnemonic: %s" % action.mnemonic,
        ).that_dict(action.env).contains_at_least({"LLVM_PROFDATA_ENV_KEY": "LLVM_PROFDATA_ENV_VALUE"})

        env.expect.where(
            detail = "mnemonic: %s" % action.mnemonic,
        ).that_dict(action.env).keys().contains("PATH")

def _test_fdo_profdata_env_impl(env, target):
    _assert_profdata_env(env, target, ["LLVMProfDataAction"])

def _test_csfdo_profdata_merge_env(name, **kwargs):
    """Tests that LLVMProfDataMergeAction gets env vars from the feature configuration.

    CS-FDO requires both --fdo_optimize and --cs_fdo_profile, triggering a merge action.
    """
    native.genrule(
        name = name + "_profraw",
        outs = [name + "/profile.profraw"],
        cmd = "touch $@",
    )

    fdo_profile(
        name = name + "_profile",
        profile = name + "_profraw",
    )

    config = _fdo_config_settings(name)
    config["//command_line_option:cs_fdo_profile"] = str(Label("//tests/cc/common:cs_fdo_profile"))
    analysis_test(
        name = name,
        impl = _test_csfdo_profdata_merge_env_impl,
        target = "//tests/cc/testutil/toolchains:cc-compiler-k8-compiler",
        config_settings = config,
        **kwargs
    )

def _test_csfdo_profdata_merge_env_impl(env, target):
    _assert_profdata_env(env, target, ["LLVMProfDataMergeAction"])

def cc_fdo_env_tests(name):
    """Creates tests for FDO actions.

    Args:
        name: The name of the test suite.
    """
    native.genrule(
        name = "cs_fdo_profraw",
        outs = ["cs_profile.profraw"],
        cmd = "touch $@",
    )

    fdo_profile(
        name = "cs_fdo_profile",
        profile = ":cs_fdo_profraw",
    )

    tests = []
    if _bazel_version_ge("9.0.0"):
        tests = [
            _test_fdo_profdata_env,
            _test_csfdo_profdata_merge_env,
        ]
    test_suite(
        name = name,
        tests = tests,
    )
