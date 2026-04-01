"""Tests for cc_common APIs"""

load("@bazel_features//:features.bzl", "bazel_features")
load("@rules_testing//lib:analysis_test.bzl", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching")
load("@rules_testing//lib:util.bzl", "TestingAspectInfo", "util")
load("//cc:cc_library.bzl", "cc_library")
load("//cc/common:cc_info.bzl", "CcInfo")
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test")
load("//tests/cc/testutil:cc_info_subject.bzl", "cc_info_subject")

def _test_same_cc_file_twice(name):
    util.helper_target(
        native.filegroup,
        name = name + "/a1",
        srcs = ["a.cc"],
    )
    util.helper_target(
        native.filegroup,
        name = name + "/a2",
        srcs = ["a.cc"],
    )
    util.helper_target(
        cc_library,
        name = name + "/a",
        srcs = [
            name + "/a1",
            name + "/a2",
        ],
    )

    cc_analysis_test(
        name = name,
        impl = _test_same_cc_file_twice_impl,
        target = name + "/a",
        expect_failure = True,
    )

def _test_same_cc_file_twice_impl(env, target):
    expected_msg = "Artifact '{package}/a.cc' is duplicated".format(package = target.label.package)
    env.expect.that_target(target).failures().contains_predicate(
        matching.custom(
            "contains '{}'".format(expected_msg),
            lambda s: expected_msg in s,
        ),
    )

def _test_same_header_file_twice(name):
    util.helper_target(
        native.filegroup,
        name = name + "/a1",
        srcs = ["a.h"],
    )
    util.helper_target(
        native.filegroup,
        name = name + "/a2",
        srcs = ["a.h"],
    )
    util.helper_target(
        cc_library,
        name = name + "/a",
        srcs = [
            "a.cc",
            name + "/a1",
            name + "/a2",
        ],
        features = ["parse_headers"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_same_header_file_twice_impl,
        target = name + "/a",
    )

def _test_same_header_file_twice_impl(env, target):
    env.expect.that_target(target).failures().contains_exactly([])

def _test_isolated_includes(name):
    util.helper_target(
        cc_library,
        name = name + "/bang",
        srcs = ["bang.cc"],
        includes = ["bang_includes"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_isolated_includes_impl,
        target = name + "/bang",
    )

def _test_isolated_includes_impl(env, target):
    # Tests the (immediate) effect of declaring the includes attribute on a
    # cc_library.
    includes_root = target.label.package + "/bang_includes"

    subject = cc_info_subject.from_target(env, target)

    expected_includes = [
        includes_root,
        target[TestingAspectInfo].bin_path + "/" + includes_root,
    ]

    if bazel_features.cc.cc_common_is_in_rules_cc:
        # Relevant: https://github.com/bazelbuild/bazel/pull/25750:
        # "Use includes instead of system_includes for includes attr"
        subject.compilation_context().include_dirs().contains_at_least(expected_includes)
    else:
        subject.compilation_context().system_include_dirs().contains_at_least(expected_includes)

def _test_strip_include_prefix_no_virtual_includes(name):
    """Tests that strip_include_prefix without include_prefix avoids _virtual_includes."""
    util.helper_target(
        cc_library,
        name = name + "/lib",
        hdrs = ["v1/foo.h"],
        strip_include_prefix = "v1",
    )

    cc_analysis_test(
        name = name,
        impl = _test_strip_include_prefix_no_virtual_includes_impl,
        target = name + "/lib",
    )

def _test_strip_include_prefix_no_virtual_includes_impl(env, target):
    subject = cc_info_subject.from_target(env, target)

    # The include dir should be the direct stripped path, not a _virtual_includes path.
    include_dirs = subject.compilation_context().include_dirs()
    include_dirs.contains_none_of(
        [matching.custom(
            "contains '_virtual_includes'",
            lambda s: "_virtual_includes" in s,
        )],
    )

    # The direct public headers should be the original source files, not symlinks.
    direct_public_headers = target[CcInfo].compilation_context.direct_public_headers
    for header in direct_public_headers:
        if "_virtual_includes" in header.path:
            env.expect.meta.add_failure(
                "expected no _virtual_includes in header path",
                "actual: {}".format(header.path),
            )

def _test_strip_include_prefix_with_include_prefix_uses_virtual_includes(name):
    """Tests that strip_include_prefix with include_prefix still uses _virtual_includes."""
    util.helper_target(
        cc_library,
        name = name + "/lib",
        hdrs = ["v1/foo.h"],
        strip_include_prefix = "v1",
        include_prefix = "mylib",
    )

    cc_analysis_test(
        name = name,
        impl = _test_strip_include_prefix_with_include_prefix_uses_virtual_includes_impl,
        target = name + "/lib",
    )

def _test_strip_include_prefix_with_include_prefix_uses_virtual_includes_impl(env, target):
    subject = cc_info_subject.from_target(env, target)

    # When include_prefix is set, _virtual_includes should be used.
    include_dirs = subject.compilation_context().include_dirs()
    include_dirs.contains_at_least_predicates(
        [matching.custom(
            "contains '_virtual_includes'",
            lambda s: "_virtual_includes" in s,
        )],
    )

def _test_strip_include_prefix_error_not_under_prefix(name):
    """Tests that headers not under strip_include_prefix produce an error."""
    util.helper_target(
        cc_library,
        name = name + "/lib",
        hdrs = ["other/foo.h"],
        strip_include_prefix = "v1",
    )

    cc_analysis_test(
        name = name,
        impl = _test_strip_include_prefix_error_not_under_prefix_impl,
        target = name + "/lib",
        expect_failure = True,
    )

def _test_strip_include_prefix_error_not_under_prefix_impl(env, target):
    env.expect.that_target(target).failures().contains_predicate(
        matching.custom(
            "contains 'is not under the specified strip prefix'",
            lambda s: "is not under the specified strip prefix" in s,
        ),
    )

def cc_common_tests(name):
    tests = [
        _test_same_cc_file_twice,
        _test_same_header_file_twice,
        _test_isolated_includes,
    ]
    if bazel_features.cc.cc_common_is_in_rules_cc:
        tests.extend([
            _test_strip_include_prefix_no_virtual_includes,
            _test_strip_include_prefix_with_include_prefix_uses_virtual_includes,
            _test_strip_include_prefix_error_not_under_prefix,
        ])
    test_suite(
        name = name,
        tests = tests,
    )
