"""Tests the compile actions for linkstamps."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@rules_testing//lib:analysis_test.bzl", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching")
load("@rules_testing//lib:util.bzl", "util")
load("//cc:cc_binary.bzl", "cc_binary")
load("//cc:cc_library.bzl", "cc_library")
load("//cc/common:cc_common.bzl", "cc_common")
load("//cc/toolchains:fdo_profile.bzl", "fdo_profile")
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test")

def _test_linkstamp_compile_options_for_executable(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/lib",
        srcs = ["lib.cc"],
        linkstamp = "ls.cc",
    )

    util.helper_target(
        cc_binary,
        name = name + "/foo",
        deps = [name + "/lib"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_linkstamp_compile_options_for_executable_impl,
        targets = {
            "target": name + "/foo",
            "cc_toolchain": "//tests/cc/testutil/toolchains:current_cc_toolchain",
        },
        **kwargs
    )

def _test_linkstamp_compile_options_for_executable_impl(env, targets):
    target = targets.target
    cc_toolchain_info = targets.cc_toolchain[cc_common.CcToolchainInfo]
    assert_linkstamp_action = env.expect.that_target(target).action_generating("{package}/{test_name}/_objs/foo/{package}/ls.o")
    assert_linkstamp_action.argv().contains_at_least([
        "--sysroot={}".format(cc_toolchain_info.sysroot),
        "-include",
        "-DGPLATFORM=\"{}\"".format(cc_toolchain_info.toolchain_id),
        "-I.",
        "-DG3_BUILD_TARGET=\"{bindir}/{package}/{name}\"",
    ])
    assert_linkstamp_action.argv().contains_predicate(
        matching.str_matches("-DG3_TARGET_NAME=\"*//{}:{}".format(target.label.package, target.label.name)),
    )
    assert_linkstamp_action.argv().not_contains_predicate(
        matching.str_matches("-DBUILD_FDO_TYPE"),
    )

def _test_linkstamp_compile_options_for_shared_library(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/lib",
        srcs = ["lib.cc"],
        linkstamp = "ls.cc",
    )

    util.helper_target(
        cc_binary,
        name = name + "/foo",
        deps = [name + "/lib"],
        linkshared = True,
    )

    cc_analysis_test(
        name = name,
        impl = _test_linkstamp_compile_options_for_shared_library_impl,
        targets = {
            "target": name + "/foo",
            "cc_toolchain": "//tests/cc/testutil/toolchains:current_cc_toolchain",
        },
        **kwargs
    )

def _test_linkstamp_compile_options_for_shared_library_impl(env, targets):
    target = targets.target
    cc_toolchain_info = targets.cc_toolchain[cc_common.CcToolchainInfo]
    libfoo_so_name = paths.dirname(target.label.name) + "/libfoo.so"
    assert_linkstamp_action = env.expect.that_target(target).action_generating("{package}/{test_name}/_objs/libfoo.so/{package}/ls.o")
    assert_linkstamp_action.argv().contains_at_least([
        "--sysroot={}".format(cc_toolchain_info.sysroot),
        "-include",
        "-DGPLATFORM=\"{}\"".format(cc_toolchain_info.toolchain_id),
        "-I.",
        "-DG3_BUILD_TARGET=\"{bindir}/{package}/" + libfoo_so_name + "\"",
    ])
    assert_linkstamp_action.argv().contains_predicate(
        matching.str_matches("-DG3_TARGET_NAME=\"*//{}:{}".format(target.label.package, target.label.name)),
    )
    assert_linkstamp_action.argv().not_contains_predicate(
        matching.str_matches("-DBUILD_FDO_TYPE"),
    )

def _test_linkstamp_compile_pic(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/lib",
        srcs = ["lib.cc"],
        linkstamp = "ls.cc",
    )

    util.helper_target(
        cc_binary,
        name = name + "/foo",
        deps = [name + "/lib"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_linkstamp_compile_pic_impl,
        target = name + "/foo",
        config_settings = {
            "//command_line_option:force_pic": True,
        },
        **kwargs
    )

def _test_linkstamp_compile_pic_impl(env, target):
    assert_linkstamp_action = env.expect.that_target(target).action_generating("{package}/{test_name}/_objs/foo/{package}/ls.o")
    assert_linkstamp_action.argv().contains("-fPIC")

def _test_linkstamp_compile_fdo(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/lib",
        srcs = ["lib.cc"],
        linkstamp = "ls.cc",
    )

    util.helper_target(
        cc_binary,
        name = name + "/foo",
        deps = [name + "/lib"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_linkstamp_compile_fdo_impl,
        target = name + "/foo",
        config_settings = {
            "//command_line_option:fdo_instrument": "foo",
        },
        **kwargs
    )

def _test_linkstamp_compile_fdo_impl(env, target):
    assert_linkstamp_action = env.expect.that_target(target).action_generating("{package}/{test_name}/_objs/foo/{package}/ls.o")
    assert_linkstamp_action.argv().contains("-DBUILD_FDO_TYPE=\"FDO\"")

# Regression test for b/73447914 - Linkstamps were not re-built when only
# volatile data changed - they were not recompiled after changing a cc_binary
# source resulting in old timestamps.
# Assert that the relevant compilation outputs from a cc_binary are added as
# inputs to the linkstamp action to ensure the action is invalidated whenever
# any cc_binary inputs change.
def _test_linkstamp_compile_cc_binary_deps(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/lib",
        srcs = ["lib.cc"],
        linkstamp = "ls.cc",
    )

    util.helper_target(
        cc_binary,
        name = name + "/foo",
        srcs = ["foo.cc"],
        deps = [name + "/lib"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_linkstamp_compile_cc_binary_deps_impl,
        target = name + "/foo",
        **kwargs
    )

def _test_linkstamp_compile_cc_binary_deps_impl(env, target):
    assert_linkstamp_action = env.expect.that_target(target).action_generating("{package}/{test_name}/_objs/foo/{package}/ls.o")
    assert_linkstamp_action.inputs().contains_at_least([
        "{package}/_objs/{name}/foo.o",
        "{package}/{test_name}/liblib.a",
    ])

def _test_linkstamp_compile_gets_copts_from_options(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/lib",
        srcs = ["lib.cc"],
        copts = ["-copt_from_cc_library"],
        linkstamp = "ls.cc",
    )

    util.helper_target(
        cc_binary,
        name = name + "/foo",
        copts = ["-copt_from_cc_binary"],
        deps = [name + "/lib"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_linkstamp_compile_gets_copts_from_options_impl,
        target = name + "/foo",
        config_settings = {
            "//command_line_option:copt": ["-copt_from_config"],
        },
        **kwargs
    )

def _test_linkstamp_compile_gets_copts_from_options_impl(env, target):
    assert_linkstamp_action = env.expect.that_target(target).action_generating("{package}/{test_name}/_objs/foo/{package}/ls.o")
    assert_linkstamp_action.argv().contains(
        "-copt_from_config",
    )
    assert_linkstamp_action.argv().contains_none_of([
        "-copt_from_cc_library",
        "-copt_from_cc_binary",
    ])

def _test_linkstamp_compile_ignores_copts_from_attributes(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/lib",
        srcs = ["lib.cc"],
        copts = ["-copt_from_cc_library"],
        linkstamp = "ls.cc",
    )

    util.helper_target(
        cc_binary,
        name = name + "/foo",
        copts = ["-copt_from_cc_binary"],
        deps = [name + "/lib"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_linkstamp_compile_ignores_copts_from_attributes_impl,
        target = name + "/foo",
        **kwargs
    )

def _test_linkstamp_compile_ignores_copts_from_attributes_impl(env, target):
    assert_linkstamp_action = env.expect.that_target(target).action_generating("{package}/{test_name}/_objs/foo/{package}/ls.o")
    assert_linkstamp_action.argv().contains_none_of([
        "-copt_from_cc_library",
        "-copt_from_cc_binary",
    ])

def _test_linkstamp_compile_uses_memprof(name, **kwargs):
    util.helper_target(
        fdo_profile,
        name = name + "/prof",
        profile = "out.afdo",
        memprof_profile = "memprof.zip",
    )

    util.helper_target(
        cc_library,
        name = name + "/lib",
        srcs = ["lib.cc"],
        linkstamp = "ls.cc",
    )

    util.helper_target(
        cc_binary,
        name = name + "/foo",
        deps = [name + "/lib"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_linkstamp_compile_uses_memprof_impl,
        target = name + "/foo",
        config_settings = {
            "//command_line_option:compilation_mode": "opt",
            # buildifier: disable=canonical-repository
            "//command_line_option:fdo_profile": "@@//" + native.package_name() + ":" + name + "/prof",
        },
        test_features = [
            "memprof_optimize",
        ],
        **kwargs
    )

def _test_linkstamp_compile_uses_memprof_impl(env, target):
    assert_linkstamp_action = env.expect.that_target(target).action_generating("{package}/{test_name}/_objs/foo/{package}/ls.o")
    assert_linkstamp_action.argv().contains("-DBUILD_PGHO_TYPE=\"opt\"")

def cc_linkstamp_compile_tests(name):
    tests = [
        _test_linkstamp_compile_options_for_executable,
        _test_linkstamp_compile_options_for_shared_library,
        _test_linkstamp_compile_pic,
        _test_linkstamp_compile_fdo,
        _test_linkstamp_compile_cc_binary_deps,
        _test_linkstamp_compile_gets_copts_from_options,
        _test_linkstamp_compile_ignores_copts_from_attributes,
    ]

    # TODO(cmita): This is overly restrictive - the requirement is for the memprof_profile attribute (Bazel 8)
    if bazel_features.cc.cc_common_is_in_rules_cc:
        tests.extend([
            _test_linkstamp_compile_uses_memprof,
        ])

    test_suite(
        name = name,
        tests = tests,
    )
