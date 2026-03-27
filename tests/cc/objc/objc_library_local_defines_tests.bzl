"""Tests for objc_library local_defines attribute."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@rules_testing//lib:analysis_test.bzl", "test_suite")
load("@rules_testing//lib:util.bzl", "util")
load("//cc:action_names.bzl", "ACTION_NAMES")
load("//cc:objc_library.bzl", "objc_library")
load("//cc/common:cc_info.bzl", "CcInfo")
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test")
load("//tests/cc/testutil/toolchains:features.bzl", "FEATURE_NAMES")

_OBJC_ACTION_CONFIGS = [
    ACTION_NAMES.objc_compile,
    ACTION_NAMES.cpp_link_static_library,
]

def _test_local_defines_in_compile_action(name, **kwargs):
    util.helper_target(
        objc_library,
        name = name + "_lib",
        srcs = ["foo.m"],
        local_defines = ["LOCAL_DEF=1"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_local_defines_in_compile_action_impl,
        target = name + "_lib",
        with_action_configs = _OBJC_ACTION_CONFIGS,
        test_features = [FEATURE_NAMES.preprocessor_defines],
        **kwargs
    )

def _test_local_defines_in_compile_action_impl(env, target):
    compile_actions = [a for a in target.actions if a.mnemonic == "ObjcCompile"]
    env.expect.that_collection(compile_actions).has_size(1)
    env.expect.that_collection(compile_actions[0].argv).contains("-DLOCAL_DEF=1")

def _test_local_defines_not_in_cc_info(name, **kwargs):
    """local_defines should not be in CcInfo.compilation_context.defines."""
    util.helper_target(
        objc_library,
        name = name + "_lib",
        srcs = ["foo.m"],
        local_defines = ["LOCAL_DEF=1"],
        defines = ["PUBLIC_DEF=1"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_local_defines_not_in_cc_info_impl,
        target = name + "_lib",
        with_action_configs = _OBJC_ACTION_CONFIGS,
        **kwargs
    )

def _test_local_defines_not_in_cc_info_impl(env, target):
    cc_info = target[CcInfo]
    defines = cc_info.compilation_context.defines.to_list()
    env.expect.that_collection(defines).contains("PUBLIC_DEF=1")
    env.expect.that_collection(defines).not_contains("LOCAL_DEF=1")

def _test_local_defines_not_propagated_to_dependent(name, **kwargs):
    util.helper_target(
        objc_library,
        name = name + "_dep",
        srcs = ["foo.m"],
        local_defines = ["LOCAL_DEP_DEF=1"],
        defines = ["PROPAGATED_DEF=1"],
    )
    util.helper_target(
        objc_library,
        name = name + "_lib",
        srcs = ["foo.m"],
        deps = [name + "_dep"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_local_defines_not_propagated_to_dependent_impl,
        target = name + "_lib",
        with_action_configs = _OBJC_ACTION_CONFIGS,
        **kwargs
    )

def _test_local_defines_not_propagated_to_dependent_impl(env, target):
    cc_info = target[CcInfo]
    defines = cc_info.compilation_context.defines.to_list()
    env.expect.that_collection(defines).contains("PROPAGATED_DEF=1")
    env.expect.that_collection(defines).not_contains("LOCAL_DEP_DEF=1")

def objc_library_local_defines_tests(name):
    tests = []

    if bazel_features.cc.cc_common_is_in_rules_cc:
        tests.extend([
            _test_local_defines_in_compile_action,
            _test_local_defines_not_in_cc_info,
            _test_local_defines_not_propagated_to_dependent,
        ])

    test_suite(
        name = name,
        tests = tests,
    )
