"""Tests for cc_import."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@rules_testing//lib:analysis_test.bzl", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching")
load("@rules_testing//lib:util.bzl", "util")
load("//cc:cc_import.bzl", "cc_import")
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test")
load("//tests/cc/testutil:cc_info_subject.bzl", "cc_info_subject")

def _test_data_in_runfiles(name, **kwargs):
    util.helper_target(
        cc_import,
        name = name + "/import_with_data",
        hdrs = ["header.h"],
        data = ["data_file.txt"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_data_in_runfiles_impl,
        target = name + "/import_with_data",
        **kwargs
    )

def _test_data_in_runfiles_impl(env, target):
    target = env.expect.that_target(target)
    target.runfiles().contains_predicate(matching.str_endswith("/data_file.txt"))
    target.data_runfiles().contains_predicate(matching.str_endswith("/data_file.txt"))

def _test_textual_hdrs_in_compilation_context(name, **kwargs):
    util.helper_target(
        cc_import,
        name = name + "/import_with_textual_hdrs",
        hdrs = ["header.h"],
        textual_hdrs = ["textual.h"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_textual_hdrs_in_compilation_context_impl,
        target = name + "/import_with_textual_hdrs",
        **kwargs
    )

def _test_textual_hdrs_in_compilation_context_impl(env, target):
    compilation_context = cc_info_subject.from_target(env, target).compilation_context()
    compilation_context.direct_public_headers().transform(
        desc = "basename",
        map_each = lambda file: file.basename,
    ).contains_exactly(["header.h"])
    compilation_context.direct_textual_headers().transform(
        desc = "basename",
        map_each = lambda file: file.basename,
    ).contains_exactly(["textual.h"])

def cc_import_configured_target_tests(name):
    test_suite(
        name = name,
        tests = [
            _test_data_in_runfiles,
            _test_textual_hdrs_in_compilation_context,
        ] if bazel_features.cc.cc_common_is_in_rules_cc else [],
    )
