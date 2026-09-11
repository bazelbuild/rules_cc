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

def _generated_tree_artifact_impl(ctx):
    directory = ctx.actions.declare_directory(ctx.label.name)
    ctx.actions.run_shell(
        outputs = [directory],
        arguments = [directory.path, ctx.attr.filename],
        command = "mkdir -p \"$1\" && touch \"$1/$2\"",
    )
    return [DefaultInfo(files = depset([directory]))]

_generated_tree_artifact = rule(
    implementation = _generated_tree_artifact_impl,
    attrs = {"filename": attr.string(mandatory = True)},
)

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

def _test_generated_tree_artifact_sources(name):
    source_tree = name + "_sources"
    util.helper_target(
        _generated_tree_artifact,
        name = source_tree,
        filename = "generated.cc",
    )
    util.helper_target(
        cc_library,
        name = name + "_lib",
        srcs = [source_tree],
    )
    cc_analysis_test(
        name = name,
        impl = _test_generated_tree_artifact_sources_impl,
        target = name + "_lib",
    )

def _test_generated_tree_artifact_sources_impl(env, target):
    compilation_outputs = target[OutputGroupInfo].compilation_outputs.to_list()
    env.expect.that_collection(compilation_outputs).contains_predicate(
        matching.custom(
            "compiled generated source directory",
            lambda artifact: artifact.is_directory and artifact.basename.endswith("_sources"),
        ),
    )

def _test_generated_tree_artifact_headers(name):
    header_tree = name + "_headers"
    util.helper_target(
        _generated_tree_artifact,
        name = header_tree,
        filename = "generated.h",
    )
    util.helper_target(
        cc_library,
        name = name + "_lib",
        srcs = ["source.cc"],
        hdrs = [header_tree],
    )
    cc_analysis_test(
        name = name,
        impl = _test_generated_tree_artifact_headers_impl,
        target = name + "_lib",
        test_features = ["parse_headers"],
        config_settings = {
            "//command_line_option:process_headers_in_dependencies": True,
        },
    )

def _test_generated_tree_artifact_headers_impl(env, target):
    env.expect.that_collection(target[CcInfo].compilation_context.headers.to_list()).contains_predicate(
        matching.custom(
            "generated header directory",
            lambda artifact: artifact.is_directory and artifact.basename.endswith("_headers"),
        ),
    )
    compilation_outputs = target[OutputGroupInfo].compilation_outputs.to_list()
    env.expect.that_collection(compilation_outputs).contains_predicate(
        matching.custom(
            "processed generated header directory",
            lambda artifact: artifact.is_directory and artifact.basename.endswith("_headers"),
        ),
    )

def cc_library_configured_target_tests(name):
    test_suite(
        name = name,
        tests = [
            _test_cc_library_data_in_runfiles,
            _test_absolute_includes_fail,
            _test_absolute_includes_windows_fail,
            _test_generated_tree_artifact_sources,
            _test_generated_tree_artifact_headers,
        ] if bazel_features.cc.cc_common_is_in_rules_cc else [],
    )
