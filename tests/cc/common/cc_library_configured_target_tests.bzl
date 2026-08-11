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

def _test_absolute_includes_fail(name):
    util.helper_target(
        cc_library,
        name = name + "_lib",
        hdrs = ["header.h"],
        includes = ["/absolute/path"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_absolute_includes_fail_impl,
        target = name + "_lib",
        expect_failure = True,
    )

def _test_absolute_includes_fail_impl(env, target):
    expected_msg = "The path '/absolute/path' is absolute, but only relative paths are allowed."
    env.expect.that_target(target).failures().contains_predicate(
        matching.custom(
            "contains '{}'".format(expected_msg),
            lambda s: expected_msg in s,
        ),
    )

def _test_absolute_includes_windows_fail(name):
    util.helper_target(
        cc_library,
        name = name + "_lib",
        hdrs = ["header.h"],
        includes = ["C:\\absolute\\path"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_absolute_includes_windows_fail_impl,
        target = name + "_lib",
        expect_failure = True,
    )

def _test_absolute_includes_windows_fail_impl(env, target):
    expected_msg = "The path 'C:\\absolute\\path' is absolute, but only relative paths are allowed."
    env.expect.that_target(target).failures().contains_predicate(
        matching.custom(
            "contains '{}'".format(expected_msg),
            lambda s: expected_msg in s,
        ),
    )

# Only targets whose label ends in "/instrumented" are matched by the instrumentation filter below.
_COVERAGE_CONFIG_SETTINGS = {
    "//command_line_option:collect_code_coverage": "true",
    "//command_line_option:instrumentation_filter": "/instrumented$",
}

def _declare_instrumented_lib(name):
    util.empty_file(name + "/instrumented.cc")
    util.helper_target(
        cc_library,
        name = name + "/instrumented",
        srcs = [name + "/instrumented.cc"],
        hdrs = ["header.h"],
    )
    return name + "/instrumented"

# A target that is matched by the instrumentation filter is instrumented, which shows up as the
# .gcno files it declares as coverage metadata.
def _test_coverage_matching_target_is_instrumented(name, **kwargs):
    cc_analysis_test(
        name = name,
        impl = _test_coverage_target_is_instrumented_impl,
        target = _declare_instrumented_lib(name),
        config_settings = _COVERAGE_CONFIG_SETTINGS,
        **kwargs
    )

# A target that isn't matched by the instrumentation filter itself still has to be instrumented if
# it may include headers from an instrumented dependency.
def _test_coverage_dep_makes_target_instrumented(name, **kwargs):
    util.empty_file(name + "/dep_user.cc")
    util.helper_target(
        cc_library,
        name = name + "/dep_user",
        srcs = [name + "/dep_user.cc"],
        deps = [_declare_instrumented_lib(name)],
    )
    cc_analysis_test(
        name = name,
        impl = _test_coverage_target_is_instrumented_impl,
        target = name + "/dep_user",
        config_settings = _COVERAGE_CONFIG_SETTINGS,
        **kwargs
    )

def _test_coverage_implementation_dep_makes_target_instrumented(name, **kwargs):
    util.empty_file(name + "/impl_dep_user.cc")
    util.helper_target(
        cc_library,
        name = name + "/impl_dep_user",
        srcs = [name + "/impl_dep_user.cc"],
        implementation_deps = [_declare_instrumented_lib(name)],
    )
    cc_analysis_test(
        name = name,
        impl = _test_coverage_target_is_instrumented_impl,
        target = name + "/impl_dep_user",
        config_settings = _COVERAGE_CONFIG_SETTINGS,
        **kwargs
    )

# metadata_files is transitive, so it isn't sufficient to assert that it is non-empty: the .gcno
# file of the target's own source has to be in there.
def _test_coverage_target_is_instrumented_impl(env, target):
    own_gcno = target.label.name.split("/")[-1] + ".gcno"
    env.expect.that_collection(
        [f.basename for f in target[InstrumentedFilesInfo].metadata_files.to_list()],
    ).contains(own_gcno)

# A target that is neither matched by the instrumentation filter nor depends on an instrumented
# target isn't instrumented, even though coverage is enabled for the build.
def _test_coverage_unmatched_target_is_not_instrumented(name, **kwargs):
    util.empty_file(name + "/unrelated.cc")
    util.helper_target(
        cc_library,
        name = name + "/unrelated",
        srcs = [name + "/unrelated.cc"],
        hdrs = ["header.h"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_coverage_unmatched_target_is_not_instrumented_impl,
        target = name + "/unrelated",
        config_settings = _COVERAGE_CONFIG_SETTINGS,
        **kwargs
    )

def _test_coverage_unmatched_target_is_not_instrumented_impl(env, target):
    env.expect.that_collection(
        target[InstrumentedFilesInfo].metadata_files.to_list(),
    ).is_empty()

def cc_library_configured_target_tests(name):
    test_suite(
        name = name,
        tests = [
            _test_cc_library_data_in_runfiles,
            _test_absolute_includes_fail,
            _test_absolute_includes_windows_fail,
            _test_coverage_matching_target_is_instrumented,
            _test_coverage_dep_makes_target_instrumented,
            _test_coverage_implementation_dep_makes_target_instrumented,
            _test_coverage_unmatched_target_is_not_instrumented,
        ] if bazel_features.cc.cc_common_is_in_rules_cc else [],
    )
