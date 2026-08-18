"""Tests for cc_import."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@rules_testing//lib:analysis_test.bzl", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching")
load("@rules_testing//lib:util.bzl", "util")
load("//cc:cc_binary.bzl", "cc_binary")
load("//cc:cc_import.bzl", "cc_import")
load("//cc:cc_library.bzl", "cc_library")
load("//cc:defs.bzl", "CcInfo")
load("//cc/common:cc_common.bzl", "cc_common")
load("//cc/common:cc_helper.bzl", "cc_helper")
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test")
load("//tests/cc/testutil:cc_info_subject.bzl", "cc_info_subject")
load("//tests/cc/testutil:link_action_subject.bzl", "link_action_subject")

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

def _test_wrong_cc_import_definitions_fails(name, **kwargs):
    util.helper_target(
        cc_import,
        name = name + "/static_so",
        static_library = "libfoo.so",
    )

    util.helper_target(
        cc_import,
        name = name + "/shared_a",
        shared_library = "libfoo.a",
    )

    util.helper_target(
        cc_import,
        name = name + "/dll_interface_a",
        shared_library = "libfoo.dll",
        interface_library = "libfoo.a",
    )

    util.helper_target(
        cc_import,
        name = name + "/system_shared_so",
        shared_library = "libfoo.so",
        system_provided = True,
    )

    util.helper_target(
        cc_import,
        name = name + "/nosystem_interface",
        interface_library = "libfoo.ifso",
        system_provided = False,
    )

    cc_analysis_test(
        name = name,
        impl = _test_wrong_cc_import_definitions_fails_impl,
        targets = {
            "static_so": name + "/static_so",
            "shared_a": name + "/shared_a",
            "dll_interface_a": name + "/dll_interface_a",
            "system_shared_so": name + "/system_shared_so",
            "nosystem_interface": name + "/nosystem_interface",
        },
        expect_failure = True,
        **kwargs
    )

def _test_wrong_cc_import_definitions_fails_impl(env, targets):
    env.expect.that_target(targets.static_so).failures().contains_predicate(
        matching.str_matches("'*:libfoo.so' does not produce any cc_import static_library files"),
    )
    env.expect.that_target(targets.shared_a).failures().contains_predicate(
        matching.str_matches("'shared_library' does not produce any cc_import shared_library files"),
    )
    env.expect.that_target(targets.dll_interface_a).failures().contains_predicate(
        matching.str_matches("'*:libfoo.a' does not produce any cc_import interface_library files"),
    )
    env.expect.that_target(targets.system_shared_so).failures().contains_predicate(
        matching.str_matches("'shared_library' shouldn't be specified when 'system_provided' is true"),
    )
    env.expect.that_target(targets.nosystem_interface).failures().contains_predicate(
        matching.str_matches("'shared_library' should be specified when 'system_provided' is false"),
    )

def _test_runtime_only_import_on_windows(name, **kwargs):
    util.helper_target(
        cc_import,
        name = name + "/foo",
        shared_library = "libfoo.dll",
    )

    cc_analysis_test(
        name = name,
        impl = _test_runtime_only_import_on_windows_impl,
        target = name + "/foo",
        test_features = [
            "copy_dynamic_libraries_to_binary",
            "targets_windows",
        ],
        **kwargs
    )

def _test_runtime_only_import_on_windows_impl(env, target):
    assert_cc_info = cc_info_subject.from_target(env, target)
    assert_cc_info.linking_context().resolved_symlink_dynamic_library_files().is_empty()
    assert_cc_info.linking_context().dynamic_library_files().contains_exactly([
        "{package}/libfoo.dll",
    ])

    runtime_libs = cc_helper.get_dynamic_libraries_for_runtime(
        target[CcInfo].linking_context,
        linking_statically = False,
    )
    env.expect.that_collection(runtime_libs).contains_exactly_predicates([
        matching.file_basename_equals("libfoo.dll"),
    ])

def _test_static_library(name, **kwargs):
    util.helper_target(
        cc_import,
        name = name + "/foo",
        static_library = "libfoo.a",
    )

    cc_analysis_test(
        name = name,
        impl = _test_static_library_impl,
        target = name + "/foo",
        **kwargs
    )

def _test_static_library_impl(env, target):
    assert_cc_info = cc_info_subject.from_target(env, target)
    assert_cc_info.linking_context().static_library_files().contains_exactly([
        "{package}/libfoo.a",
    ])

def _test_shared_library(name, **kwargs):
    util.helper_target(
        cc_import,
        name = name + "/foo",
        shared_library = "libfoo.so",
    )

    cc_analysis_test(
        name = name,
        impl = _test_shared_library_impl,
        target = name + "/foo",
        **kwargs
    )

def _test_shared_library_impl(env, target):
    assert_cc_info = cc_info_subject.from_target(env, target)
    assert_cc_info.linking_context().resolved_symlink_dynamic_library_files().contains_exactly([
        "{package}/libfoo.so",
    ])
    assert_cc_info.linking_context().dynamic_library_files().contains_predicate(
        matching.file_path_matches("_solib*libfoo.so"),
    )

def _test_versioned_shared_library(name, **kwargs):
    util.helper_target(
        cc_import,
        name = name + "/foo",
        shared_library = "libfoo.so.1ab2.1_a2",
    )

    cc_analysis_test(
        name = name,
        impl = _test_versioned_shared_library_impl,
        target = name + "/foo",
        **kwargs
    )

def _test_versioned_shared_library_impl(env, target):
    assert_cc_info = cc_info_subject.from_target(env, target)
    assert_cc_info.linking_context().resolved_symlink_dynamic_library_files().contains_exactly([
        "{package}/libfoo.so.1ab2.1_a2",
    ])
    assert_cc_info.linking_context().dynamic_library_files().contains_predicate(
        matching.file_path_matches("_solib*libfoo.so.1ab2.1_a2"),
    )

def _test_versioned_shared_library_with_dot(name, **kwargs):
    util.helper_target(
        cc_import,
        name = name + "/foo",
        shared_library = "libfoo.qux.so.1ab2.1_a2",
    )

    cc_analysis_test(
        name = name,
        impl = _test_versioned_shared_library_with_dot_impl,
        target = name + "/foo",
        **kwargs
    )

def _test_versioned_shared_library_with_dot_impl(env, target):
    assert_cc_info = cc_info_subject.from_target(env, target)
    assert_cc_info.linking_context().resolved_symlink_dynamic_library_files().contains_exactly([
        "{package}/libfoo.qux.so.1ab2.1_a2",
    ])
    assert_cc_info.linking_context().dynamic_library_files().contains_predicate(
        matching.file_path_matches("_solib*libfoo.qux.so.1ab2.1_a2"),
    )

def _test_invalid_shared_library_version_fails(name, **kwargs):
    util.helper_target(
        cc_import,
        name = name + "/foo",
        shared_library = "libfoo.so.1ab2.ab",
    )

    cc_analysis_test(
        name = name,
        impl = _test_invalid_shared_library_version_fails_impl,
        target = name + "/foo",
        expect_failure = True,
        **kwargs
    )

def _test_invalid_shared_library_version_fails_impl(env, target):
    env.expect.that_target(target).failures().contains_predicate(
        matching.str_matches("'shared_library' does not produce any cc_import shared_library files"),
    )

def _test_shared_library_with_no_extension_fails(name, **kwargs):
    util.helper_target(
        cc_import,
        name = name + "/foo",
        shared_library = "libfoo",
    )

    cc_analysis_test(
        name = name,
        impl = _test_shared_library_with_no_extension_fails_impl,
        target = name + "/foo",
        expect_failure = True,
        **kwargs
    )

def _test_shared_library_with_no_extension_fails_impl(env, target):
    env.expect.that_target(target).failures().contains_predicate(
        matching.str_matches("'shared_library' does not produce any cc_import shared_library files"),
    )

def _test_interface_shared_library(name, **kwargs):
    util.helper_target(
        cc_import,
        name = name + "/foo",
        shared_library = "libfoo.so",
        interface_library = "libfoo.ifso",
    )

    cc_analysis_test(
        name = name,
        impl = _test_interface_shared_library_impl,
        target = name + "/foo",
        **kwargs
    )

def _test_interface_shared_library_impl(env, target):
    assert_cc_info = cc_info_subject.from_target(env, target)
    assert_cc_info.linking_context().resolved_symlink_interface_library_files().contains_exactly([
        "{package}/libfoo.ifso",
    ])
    assert_cc_info.linking_context().resolved_symlink_dynamic_library_files().contains_exactly([
        "{package}/libfoo.so",
    ])
    assert_cc_info.linking_context().interface_library_files().contains_predicate(
        matching.file_path_matches("_solib*libfoo.ifso"),
    )
    assert_cc_info.linking_context().dynamic_library_files().contains_predicate(
        matching.file_path_matches("_solib*libfoo.so"),
    )

def _test_static_and_shared_libraries(name, **kwargs):
    util.helper_target(
        cc_import,
        name = name + "/foo",
        static_library = "libfoo.a",
        shared_library = "libfoo.so",
    )

    cc_analysis_test(
        name = name,
        impl = _test_static_and_shared_libraries_impl,
        target = name + "/foo",
        **kwargs
    )

def _test_static_and_shared_libraries_impl(env, target):
    assert_cc_info = cc_info_subject.from_target(env, target)
    assert_cc_info.linking_context().static_library_files().contains_exactly([
        "{package}/libfoo.a",
    ])
    assert_cc_info.linking_context().resolved_symlink_dynamic_library_files().contains_exactly([
        "{package}/libfoo.so",
    ])
    assert_cc_info.linking_context().dynamic_library_files().contains_predicate(
        matching.file_path_matches("_solib*libfoo.so"),
    )

def _test_always_link_static_library(name, **kwargs):
    util.helper_target(
        cc_import,
        name = name + "/foo",
        static_library = "libfoo.a",
        alwayslink = True,
    )

    cc_analysis_test(
        name = name,
        impl = _test_always_link_static_library_impl,
        target = name + "/foo",
        **kwargs
    )

def _test_always_link_static_library_impl(env, target):
    assert_library = cc_info_subject.from_target(env, target).linking_context().libraries_to_link().singleton()
    assert_library.alwayslink().equals(True)

def _test_system_provided(name, **kwargs):
    util.helper_target(
        cc_import,
        name = name + "/foo",
        interface_library = "libfoo.ifso",
        system_provided = True,
    )

    cc_analysis_test(
        name = name,
        impl = _test_system_provided_impl,
        target = name + "/foo",
        **kwargs
    )

def _test_system_provided_impl(env, target):
    assert_cc_info = cc_info_subject.from_target(env, target)
    assert_cc_info.linking_context().resolved_symlink_interface_library_files().contains_exactly([
        "{package}/libfoo.ifso",
    ])
    assert_cc_info.linking_context().dynamic_library_files().is_empty()

def _test_providing_header_files(name, **kwargs):
    util.helper_target(
        cc_import,
        name = name + "/foo",
        static_library = "libfoo.a",
        hdrs = ["foo.h"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_providing_header_files_impl,
        target = name + "/foo",
        **kwargs
    )

def _test_providing_header_files_impl(env, target):
    assert_cc_info = cc_info_subject.from_target(env, target)
    assert_cc_info.compilation_context().headers().contains(
        "{package}/foo.h",
    )
    assert_cc_info.compilation_context().direct_public_headers().contains_exactly_predicates([
        matching.file_basename_equals("foo.h"),
    ])

def _test_shared_library_adds_rpath_entry(name, **kwargs):
    util.helper_target(
        cc_import,
        name = name + "/foo",
        shared_library = "libfoo.so",
    )

    util.helper_target(
        cc_binary,
        name = name + "/bin",
        deps = [name + "/foo"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_shared_library_adds_rpath_entry_impl,
        target = name + "/bin",
        **kwargs
    )

def _test_shared_library_adds_rpath_entry_impl(env, target):
    assert_action = link_action_subject.from_target(env, target)
    assert_action.argv().contains_at_least_predicates([
        matching.equals_wrapper("-Xlinker"),
        matching.equals_wrapper("-rpath"),
        matching.equals_wrapper("-Xlinker"),
        matching.str_matches("*/_solib*/*Sfoo___U*"),
    ]).in_order()

def _test_transition_impl(_settings, _attr):
    return {"//command_line_option:copt": ["-DFLAG"]}

test_transition = transition(
    implementation = _test_transition_impl,
    inputs = [],
    outputs = ["//command_line_option:copt"],
)

def _apply_test_transition_impl(ctx):
    cc_infos = [dep[CcInfo] for dep in ctx.attr.deps]
    merged = cc_common.merge_cc_infos(cc_infos = cc_infos)
    return [merged]

apply_test_transition = rule(
    implementation = _apply_test_transition_impl,
    attrs = {
        "deps": attr.label_list(cfg = test_transition),
    },
)

def _test_shared_library_adds_rpath_entry_under_transition(name, **kwargs):
    util.helper_target(
        cc_import,
        name = name + "/foo",
        shared_library = "libfoo.so",
    )

    util.helper_target(
        cc_library,
        name = name + "/bar",
        deps = [name + "/foo"],
    )

    util.helper_target(
        apply_test_transition,
        name = name + "/transitioned_bar",
        deps = [name + "/bar"],
    )

    util.helper_target(
        cc_binary,
        name = name + "/bin",
        deps = [name + "/transitioned_bar"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_shared_library_adds_rpath_entry_under_transition_impl,
        target = name + "/bin",
        **kwargs
    )

def _test_shared_library_adds_rpath_entry_under_transition_impl(env, target):
    assert_action = link_action_subject.from_target(env, target)
    assert_action.argv().contains_at_least_predicates([
        matching.equals_wrapper("-Xlinker"),
        matching.equals_wrapper("-rpath"),
        matching.equals_wrapper("-Xlinker"),
        matching.str_matches("*/_solib*/*Sfoo___U*"),
    ]).in_order()

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
    tests = [
        _test_wrong_cc_import_definitions_fails,
        _test_runtime_only_import_on_windows,
        _test_static_library,
        _test_shared_library,
        _test_versioned_shared_library,
        _test_versioned_shared_library_with_dot,
        _test_invalid_shared_library_version_fails,
        _test_shared_library_with_no_extension_fails,
        _test_interface_shared_library,
        _test_static_and_shared_libraries,
        _test_always_link_static_library,
        _test_system_provided,
        _test_providing_header_files,
        _test_shared_library_adds_rpath_entry,
        _test_shared_library_adds_rpath_entry_under_transition,
    ]
    if bazel_features.cc.cc_common_is_in_rules_cc:
        tests.extend([
            _test_data_in_runfiles,
            _test_textual_hdrs_in_compilation_context,
        ])

    test_suite(
        name = name,
        tests = tests,
    )
