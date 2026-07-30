"""Tests for bad dependencies between C++ libraries."""

load("@rules_testing//lib:analysis_test.bzl", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching")
load("@rules_testing//lib:util.bzl", "util")
load("//cc:cc_library.bzl", "cc_library")
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test")

def test_reject_unknown_source_file(name, **kwargs):
    util.helper_target(
        rule = cc_library,
        name = name + "/foo",
        srcs = ["unknown.oops"],
    )

    cc_analysis_test(
        name = name,
        impl = test_reject_unknown_source_file_impl,
        target = name + "/foo",
        expect_failure = True,
        **kwargs
    )

def test_reject_unknown_source_file_impl(env, target):
    env.expect.that_target(target).failures().contains_predicate(
        matching.str_matches("source file '*:unknown.oops' is misplaced here"),
    )

def test_reject_bad_generated_file(name, **kwargs):
    util.helper_target(
        rule = native.genrule,
        name = name + "/gen",
        outs = [name + "/bad.oops"],
        cmd = "touch $@",
    )

    util.helper_target(
        rule = cc_library,
        name = name + "/foo",
        srcs = [name + "/gen"],
    )

    cc_analysis_test(
        name = name,
        impl = test_reject_bad_generated_file_impl,
        target = name + "/foo",
        expect_failure = True,
        **kwargs
    )

def test_reject_bad_generated_file_impl(env, target):
    env.expect.that_target(target).failures().contains_predicate(
        matching.str_matches("attribute srcs: '*/gen' does not produce any cc_library srcs files"),
    )

def test_accept_mixed_generated_files(name, **kwargs):
    util.helper_target(
        rule = native.genrule,
        name = name + "/gen",
        outs = [
            name + "/bad.oops",
            name + "/good.cc",
        ],
        cmd = "touch $(OUTS)",
    )

    util.helper_target(
        rule = cc_library,
        name = name + "/foo",
        srcs = [name + "/gen"],
    )

    cc_analysis_test(
        name = name,
        impl = test_accept_mixed_generated_files_impl,
        target = name + "/foo",
        **kwargs
    )

def test_accept_mixed_generated_files_impl(env, target):
    env.expect.that_target(target).action_named("CppCompile").inputs().contains(
        "{package}/{test_name}/good.cc",
    )
    env.expect.that_target(target).action_named("CppCompile").inputs().not_contains(
        "{package}/{test_name}/bad.oops",
    )

def cc_bad_dependencies_tests(name):
    test_suite(
        name = name,
        tests = [
            test_reject_unknown_source_file,
            test_reject_bad_generated_file,
            test_accept_mixed_generated_files,
        ],
    )
