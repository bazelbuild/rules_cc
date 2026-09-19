"""Tests for the resolution of cxx_builtin_include_directories by cc_toolchain."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@rules_testing//lib:analysis_test.bzl", "test_suite")
load("//cc/common:cc_common.bzl", "cc_common")
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test")

def _test_package_include_directories_use_toolchain_repo_mapping(name):
    cc_analysis_test(
        name = name,
        impl = _test_package_include_directories_use_toolchain_repo_mapping_impl,
        target = "@cross_repo_test//toolchain_include_dirs:toolchain",
    )

def _test_package_include_directories_use_toolchain_repo_mapping_impl(env, target):
    test_repo_root = Label("@cross_repo_test//toolchain_include_dirs:toolchain").workspace_root
    rules_cc_root = Label("//cc:BUILD").workspace_root
    env.expect.that_collection(
        target[cc_common.CcToolchainInfo].built_in_include_directories,
    ).contains_exactly([
        paths.join(test_repo_root, "toolchain_include_dirs/include"),
        paths.join(test_repo_root, "toolchain_include_dirs/other"),
        paths.join(rules_cc_root, "cc"),
    ]).in_order()

def cc_toolchain_include_directories_tests(name):
    tests = []
    if bazel_features.cc.cc_common_is_in_rules_cc:
        tests.append(_test_package_include_directories_use_toolchain_repo_mapping)

    test_suite(
        name = name,
        tests = tests,
    )
