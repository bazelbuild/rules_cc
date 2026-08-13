"""Tests for C++ linking action."""

load("@rules_testing//lib:analysis_test.bzl", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching", "subjects")
load("@rules_testing//lib:util.bzl", "util")
load("//cc:cc_binary.bzl", "cc_binary")
load("//cc:cc_library.bzl", "cc_library")
load("//cc:cc_test.bzl", "cc_test")
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test")
load("//tests/cc/testutil:link_action_subject.bzl", "link_action_subject")

def _has_constraint(env, platform_target):
    return env.ctx.target_platform_has_constraint(
        platform_target[platform_common.ConstraintValueInfo],
    )

def _test_linkopts_and_lib_srcs_order(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/foo",
        srcs = [
            "somedir/libbar.so",
            "someotherdir/qux.so",
        ],
        linkopts = [
            "-ldl",
            "-lutil",
        ],
    )

    cc_analysis_test(
        name = name,
        attrs = {
            "_is_macos": attr.label(default = "@platforms//os:macos"),
        },
        impl = _test_linkopts_and_lib_srcs_order_impl,
        target = name + "/foo",
        **kwargs
    )

def _extract_x_linker_args(args):
    x_linker_args = []
    for i in range(len(args)):
        if args[i] == "-Xlinker":
            arg = " ".join((args[i], args[i + 1]))
            x_linker_args.append(arg)
    return x_linker_args

def _test_linkopts_and_lib_srcs_order_impl(env, target):
    assert_link_action = link_action_subject.from_target(env, target)
    is_macos = _has_constraint(env, env.ctx.attr._is_macos)
    assert_link_action.argv().contains_at_least_predicates([
        matching.str_matches("-L*somedir"),
        matching.str_matches("-L*someotherdir"),
        matching.equals_wrapper("-lbar"),
        matching.str_endswith("qux.so") if is_macos else matching.equals_wrapper("-l:qux.so"),
        matching.equals_wrapper("-ldl"),
        matching.equals_wrapper("-lutil"),
    ]).in_order()

    x_linker_args = _extract_x_linker_args(assert_link_action.argv().actual)
    assert_x_linker_args = subjects.collection(
        x_linker_args,
        sortable = False,
        meta = assert_link_action.meta.derive("argv"),
    )
    assert_x_linker_args.contains_at_least_predicates([
        matching.equals_wrapper("-Xlinker -rpath"),
        matching.str_matches("-Xlinker *somedir"),
        matching.equals_wrapper("-Xlinker -rpath"),
        matching.str_matches("-Xlinker *someotherdir"),
    ]).in_order()

def _test_dynamic_mode_libraries_unaffected_by_legacy_whole_archive(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/bar",
        srcs = ["bar.cc"],
        alwayslink = True,
    )

    util.helper_target(
        cc_binary,
        name = name + "/foo",
        deps = [name + "/bar"],
        srcs = ["foo.cc"],
    )

    util.helper_target(
        cc_binary,
        name = name + "/libfoo.so",
        srcs = ["foo.cc"],
        deps = [name + "/bar"],
        linkshared = True,
        linkstatic = False,
    )

    cc_analysis_test(
        name = name,
        impl = _test_dynamic_mode_libraries_unaffected_by_legacy_whole_archive_impl,
        targets = {
            "default": name + "/foo",
            "dynamic_lib": name + "/libfoo.so",
        },
        config_settings = {
            "//command_line_option:legacy_whole_archive": True,
        },
        test_features = [
            "supports_dynamic_linker",
        ],
        attrs = {
            "_is_macos": attr.label(default = "@platforms//os:macos"),
        },
        **kwargs
    )

def _test_dynamic_mode_libraries_unaffected_by_legacy_whole_archive_impl(env, targets):
    is_macos = _has_constraint(env, env.ctx.attr._is_macos)
    whole_archive_arg_predicate = matching.equals_wrapper("-Wl,-whole-archive")
    if is_macos:
        whole_archive_arg_predicate = matching.str_matches("-Wl,-force_load")

    # verify a regular binary is affected to ensure we're testing what we think we're testing
    assert_link_action_default = link_action_subject.from_target(env, targets.default)
    assert_link_action_default.argv().contains_predicate(whole_archive_arg_predicate)

    assert_link_action_dynamic = link_action_subject.from_target(env, targets.dynamic_lib)
    assert_link_action_dynamic.argv().not_contains_predicate(whole_archive_arg_predicate)

def _test_dynamic_mode_srcs_with_feature(name, **kwargs):
    util.helper_target(
        cc_test,
        name = name + "/foo_test",
        srcs = ["foo.cc"],
        features = ["dynamic_link_test_srcs"],
    )

    util.helper_target(
        cc_test,
        name = name + "/foo_test_static",
        srcs = ["foo.cc"],
        features = ["dynamic_link_test_srcs"],
        linkstatic = True,
    )

    util.helper_target(
        cc_binary,
        name = name + "/foo_bin",
        srcs = ["foo.cc"],
    )

    cc_analysis_test(
        name,
        impl = _test_dynamic_mode_srcs_with_feature_impl,
        attrs = {
            "_is_windows": attr.label(default = "@platforms//os:windows"),
        },
        targets = {
            "foo_test": name + "/foo_test",
            "foo_test_static": name + "/foo_test_static",
            "foo_bin": name + "/foo_bin",
        },
        test_features = [
            "supports_pic",
            "supports_dynamic_linker",
            "supports_interface_shared_libraries",
        ],
        config_settings = {
            "//command_line_option:force_pic": "True",
        },
        **kwargs
    )

def _test_dynamic_mode_srcs_with_feature_impl(env, targets):
    if _has_constraint(env, env.ctx.attr._is_windows):
        # TODO: Fix this test on Windows.
        return
    assert_test_link_action = link_action_subject.from_target(env, targets.foo_test)
    assert_test_link_action.inputs().contains_predicate(
        matching.file_path_matches("_solib_*libfoo_Utest.ifso"),
    )
    assert_test_link_action.argv().contains_predicate(
        matching.str_matches("_solib_*libfoo_Utest.ifso"),
    )
    assert_test_runfiles = env.expect.that_target(targets.foo_test).runfiles()
    assert_test_runfiles.contains_predicate(
        matching.str_matches("_solib_*libfoo_Utest.so"),
    )

    assert_test_static_link_action = link_action_subject.from_target(env, targets.foo_test_static)
    assert_test_static_link_action.inputs().contains(
        "{package}/_objs/{name}/foo.pic.o",
    )
    assert_test_static_runfiles = env.expect.that_target(targets.foo_test_static).runfiles()
    assert_test_static_runfiles.contains_exactly([
        "{workspace}/{package}/{name}",
    ])

    assert_bin_link_action = link_action_subject.from_target(env, targets.foo_bin)
    assert_bin_link_action.inputs().contains(
        "{package}/_objs/{name}/foo.pic.o",
    )
    assert_bin_runfiles = env.expect.that_target(targets.foo_bin).runfiles()
    assert_bin_runfiles.contains_exactly([
        "{workspace}/{package}/{name}",
    ])

def _test_dynamic_mode_swrcs_without_feature(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/foo",
        srcs = ["foo.cc"],
        features = [
            "-static_link_test_srcs",
        ],
    )

    cc_analysis_test(
        name = name,
        impl = _test_dynamic_mode_swrcs_without_feature_impl,
        target = name + "/foo",
        test_features = [
            "supports_pic",
            "supports_dynamic_linker",
            "supports_interface_shared_libraries",
        ],
        config_settings = {
            "//command_line_option:force_pic": "True",
            "//command_line_option:dynamic_mode": "default",
        },
        **kwargs
    )

def _test_dynamic_mode_swrcs_without_feature_impl(env, target):
    assert_link_action = link_action_subject.from_target(env, target)
    assert_link_action.inputs().contains("{package}/_objs/{name}/foo.pic.o")
    assert_link_action.inputs().not_contains_predicate(
        matching.file_path_matches("libfoo.ifso"),
    )
    env.expect.that_target(target).runfiles().contains_exactly([
        "{workspace}/{package}/{name}",
    ])

def _test_interface_output_for_dynamic_library(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/foo",
        srcs = ["foo.cc"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_interface_output_for_dynamic_library_impl,
        target = name + "/foo",
        test_features = [
            "supports_dynamic_linker",
            "supports_interface_shared_libraries",
        ],
        **kwargs
    )

def _test_interface_output_for_dynamic_library_impl(env, target):
    assert_link_action = env.expect.that_target(target).action_generating(
        "{package}/{test_name}/libfoo.so",
    )
    assert_link_action.mnemonic().equals("CppLink")
    assert_link_action.inputs().contains_predicate(
        matching.file_path_matches("link_dynamic_library"),
    )

def _test_pie_disabled_for_shared_libraries(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/foo",
        srcs = ["foo.cc"],
        linkopts = [
            "-pie",
            "-other",
            "-pie",
        ],
        linkshared = True,
    )

    cc_analysis_test(
        name = name,
        impl = _test_pie_disabled_for_shared_libraries_impl,
        target = name + "/foo",
        **kwargs
    )

def _test_pie_disabled_for_shared_libraries_impl(env, target):
    assert_link_action = env.expect.that_target(target).action_named("CppLink")
    assert_link_action.argv().contains("-other")
    assert_link_action.argv().not_contains("-pie")

def _test_pie_option_kept_for_executables(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/foo",
        srcs = ["foo.cc"],
        linkopts = [
            "-pie",
            "-other",
            "-pie",
        ],
        linkshared = False,
    )

    cc_analysis_test(
        name = name,
        impl = _test_pie_option_kept_for_executables_impl,
        target = name + "/foo",
        **kwargs
    )

def _test_pie_option_kept_for_executables_impl(env, target):
    assert_link_action = env.expect.that_target(target).action_named("CppLink")
    assert_link_action.argv().contains_at_least([
        "-pie",
        "-other",
        "-pie",
    ]).in_order()

def _test_linkopts_come_after_linker_inputs(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/bar",
        srcs = ["bar.cc"],
    )

    util.helper_target(
        cc_library,
        name = name + "/baz",
        srcs = ["baz.cc"],
    )

    util.helper_target(
        cc_binary,
        name = name + "/foo",
        srcs = ["foo.cc"],
        deps = [
            name + "/bar",
            name + "/baz",
        ],
        linkopts = [
            "fake_linkopt_1",
            "fake_linkopt_2",
        ],
    )

    cc_analysis_test(
        name = name,
        impl = _test_linkopts_come_after_linker_inputs_impl,
        target = name + "/foo",
        **kwargs
    )

def _test_linkopts_come_after_linker_inputs_impl(env, target):
    assert_link_action = link_action_subject.from_target(env, target)
    link_action = assert_link_action.actual
    inputs = link_action.inputs.to_list()
    argv_map = {}
    for n, arg in enumerate(link_action.argv):
        argv_map[arg] = n
    max_argv_idx = 0
    for input in inputs:
        max_argv_idx = max(max_argv_idx, argv_map.get(input.path, 0))

    assert_link_action.argv().contains_at_least([
        link_action.argv[max_argv_idx],
        "fake_linkopt_1",
        "fake_linkopt_2",
    ]).in_order()

def _test_linkstamp_objects_exposed(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/bar",
        linkstamp = "linkstamp.cc",
    )

    util.helper_target(
        cc_binary,
        name = name + "/foo",
        deps = [
            name + "/bar",
        ],
    )

    cc_analysis_test(
        name = name,
        impl = _test_linkstamp_objects_exposed_impl,
        target = name + "/foo",
        **kwargs
    )

def _test_linkstamp_objects_exposed_impl(env, target):
    assert_link_action = link_action_subject.from_target(env, target)
    assert_link_action.inputs().contains(
        "{package}/{test_name}/_objs/foo/{package}/linkstamp.o",
    )

def cc_link_action_tests(name):
    tests = [
        _test_linkopts_and_lib_srcs_order,
        _test_dynamic_mode_libraries_unaffected_by_legacy_whole_archive,
        _test_dynamic_mode_srcs_with_feature,
        _test_dynamic_mode_swrcs_without_feature,
        _test_interface_output_for_dynamic_library,
        _test_pie_disabled_for_shared_libraries,
        _test_pie_option_kept_for_executables,
        _test_linkopts_come_after_linker_inputs,
        _test_linkstamp_objects_exposed,
    ]
    test_suite(
        name = name,
        tests = tests,
    )
