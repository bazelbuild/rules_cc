"""Tests for cc_library."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@rules_testing//lib:analysis_test.bzl", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching")
load("@rules_testing//lib:util.bzl", "util")
load("//cc:cc_library.bzl", "cc_library")
load("//cc/common:cc_info.bzl", "CcInfo")
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test")

def _src_with_runfiles_impl(ctx):
    src = ctx.actions.declare_file(ctx.label.name + ".cc")
    runfile = ctx.actions.declare_file(ctx.label.name + "_runfile.txt")
    ctx.actions.write(src, "")
    ctx.actions.write(runfile, "")
    return [DefaultInfo(
        files = depset([src]),
        default_runfiles = ctx.runfiles(files = [runfile]),
    )]

_src_with_runfiles = rule(implementation = _src_with_runfiles_impl)

def _cc_dep_with_runfiles_impl(ctx):
    runfile = ctx.actions.declare_file(ctx.label.name + "_runfile.txt")
    ctx.actions.write(runfile, "")
    return [
        DefaultInfo(default_runfiles = ctx.runfiles(files = [runfile])),
        CcInfo(),
    ]

_cc_dep_with_runfiles = rule(implementation = _cc_dep_with_runfiles_impl)

def _test_cc_library_data_in_runfiles(name, **kwargs):
    srcs_runfiles = name + "_srcs_runfiles"
    deps_runfiles = name + "_deps_runfiles"
    implementation_deps_runfiles = name + "_implementation_deps_runfiles"

    util.helper_target(
        _src_with_runfiles,
        name = srcs_runfiles,
    )
    util.helper_target(
        _cc_dep_with_runfiles,
        name = deps_runfiles,
    )
    util.helper_target(
        _cc_dep_with_runfiles,
        name = implementation_deps_runfiles,
    )
    util.helper_target(
        cc_library,
        name = name + "_lib_with_data",
        srcs = [
            "source.cc",
            srcs_runfiles,
        ],
        hdrs = ["header.h"],
        data = ["data_file.txt"],
        deps = [deps_runfiles],
        implementation_deps = [implementation_deps_runfiles],
    )
    cc_analysis_test(
        name = name,
        impl = _test_cc_library_data_in_runfiles_impl,
        target = name + "_lib_with_data",
        **kwargs
    )

def _test_cc_library_data_in_runfiles_impl(env, target):
    target = env.expect.that_target(target)
    for suffix in [
        "/data_file.txt",
        "_srcs_runfiles_runfile.txt",
        "_deps_runfiles_runfile.txt",
        "_implementation_deps_runfiles_runfile.txt",
    ]:
        target.runfiles().contains_predicate(matching.str_endswith(suffix))
        target.data_runfiles().contains_predicate(matching.str_endswith(suffix))

    target.runfiles().not_contains_predicate(matching.str_endswith(".a"))
    target.data_runfiles().not_contains_predicate(matching.str_endswith(".a"))

def cc_library_configured_target_tests(name):
    test_suite(
        name = name,
        tests = [
            _test_cc_library_data_in_runfiles,
        ] if bazel_features.cc.cc_common_is_in_rules_cc else [],
    )
