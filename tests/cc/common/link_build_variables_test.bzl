"""Tests for link build variables."""

load("@rules_testing//lib:analysis_test.bzl", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching")
load("@rules_testing//lib:util.bzl", "util")
load("//cc:cc_binary.bzl", "cc_binary")
load("//cc:cc_library.bzl", "cc_library")
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test")
load("//tests/cc/testutil:link_action_subject.bzl", "link_action_subject")

def _cc_library_setup(name):
    util.helper_target(
        cc_library,
        name = name + "_lib",
        srcs = ["a.cc"],
    )

def _cc_library_nodeps_dynamic_library_action(env, target):
    action_subject = env.expect.that_target(target).action_generating("{package}/lib{name}.so")
    return link_action_subject.new(action_subject.actual, action_subject.meta)

def _cc_library_static_library_action(env, target):
    action_subject = env.expect.that_target(target).action_generating("{package}/lib{name}.a")
    return link_action_subject.new(action_subject.actual, action_subject.meta)

def _test_force_pic_build_variable(name):
    util.helper_target(
        cc_binary,
        name = name + "_bin",
        srcs = ["a.cc"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_force_pic_build_variable_impl,
        target = name + "_bin",
        with_features = ["supports_pic", "force_pic_flags"],
        config_settings = {
            "//command_line_option:force_pic": True,
        },
    )

def _test_force_pic_build_variable_impl(env, target):
    action = link_action_subject.from_target(env, target)
    action.argv().contains("--force-pic-flag")

def _test_libraries_to_link_are_exported(name):
    _cc_library_setup(name)

    cc_analysis_test(
        name = name,
        impl = _test_libraries_to_link_are_exported_impl,
        target = name + "_lib",
        with_features = ["supports_dynamic_linker", "libraries_to_link"],
    )

def _test_libraries_to_link_are_exported_impl(env, target):
    action = _cc_library_nodeps_dynamic_library_action(env, target)
    action.argv().contains_predicate(
        matching.custom(
            "contains a.o or a.pic.o",
            lambda s: s.startswith("--library-to-link=") and any([s.endswith(ext) for ext in ["a.o", "a.pic.o", "a.obj", "a.pic.obj"]]),
        ),
    )

def _dummy_file_impl(ctx):
    out = ctx.actions.declare_file(ctx.attr.filename)
    ctx.actions.write(out, "")
    return [DefaultInfo(files = depset([out]))]

_dummy_file = rule(
    implementation = _dummy_file_impl,
    attrs = {"filename": attr.string(mandatory = True)},
)

def _dummy_lib_and_bin_setup(name, filename):
    lib_target = name + "_lib"
    util.helper_target(
        _dummy_file,
        name = lib_target,
        filename = filename,
    )
    util.helper_target(
        cc_binary,
        name = name + "_bin",
        srcs = [lib_target],
    )

def _test_library_search_directories_are_exported(name):
    _dummy_lib_and_bin_setup(name, "some-dir/bar.so")

    cc_analysis_test(
        name = name,
        impl = _test_library_search_directories_are_exported_impl,
        target = name + "_bin",
        with_features = ["library_search_directories"],
    )

def _test_library_search_directories_are_exported_impl(env, target):
    action = link_action_subject.from_target(env, target)
    action.argv().contains_predicate(
        matching.custom(
            "contains 'some-dir'",
            lambda s: "some-dir" in s,
        ),
    )

def _test_link_simple_lib_name(name):
    _dummy_lib_and_bin_setup(name, "some-dir/libbar.so")

    cc_analysis_test(
        name = name,
        impl = _test_link_simple_lib_name_impl,
        target = name + "_bin",
        with_features = ["libraries_to_link"],
    )

def _test_link_simple_lib_name_impl(env, target):
    action = link_action_subject.from_target(env, target)
    action.argv().contains("--library-to-link=bar")

def _test_link_versioned_lib_name(name):
    _dummy_lib_and_bin_setup(name, "some-dir/libbar.so.1a.2")

    cc_analysis_test(
        name = name,
        impl = _test_link_versioned_lib_name_impl,
        target = name + "_bin",
        with_features = ["libraries_to_link"],
    )

def _test_link_versioned_lib_name_impl(env, target):
    action = link_action_subject.from_target(env, target)
    action.argv().contains("--library-to-link=libbar.so.1a.2")

def _test_link_unusual_lib_name(name):
    _dummy_lib_and_bin_setup(name, "some-dir/_libbar.so")

    cc_analysis_test(
        name = name,
        impl = _test_link_unusual_lib_name_impl,
        target = name + "_bin",
        with_features = ["libraries_to_link"],
    )

def _test_link_unusual_lib_name_impl(env, target):
    action = link_action_subject.from_target(env, target)
    action.argv().contains("--library-to-link=_libbar.so")

def _test_interface_library_building_variables_when_generation_possible(name):
    _cc_library_setup(name)

    cc_analysis_test(
        name = name,
        impl = _test_interface_library_building_variables_when_generation_possible_impl,
        target = name + "_lib",
        with_features = [
            "supports_dynamic_linker",
            "supports_interface_shared_libraries",
            "uses_ifso_variables",
        ],
    )

def _test_interface_library_building_variables_when_generation_possible_impl(env, target):
    action = _cc_library_nodeps_dynamic_library_action(env, target)
    action.argv().contains("--generate-interface-library=yes")
    action.argv().contains_at_least_predicates([
        matching.str_matches("--interface-library-input=*lib{name}.so".format(name = target.label.name)),
        matching.str_matches("--interface-library-output=*lib{name}.ifso".format(name = target.label.name)),
        matching.str_matches("--interface-library-builder=*build_interface_so"),
    ])

def _test_interface_library_building_variables_when_generation_not_allowed(name):
    _cc_library_setup(name)

    cc_analysis_test(
        name = name,
        impl = _test_interface_library_building_variables_when_generation_not_allowed_impl,
        target = name + "_lib",
        with_features = [
            "supports_interface_shared_libraries",
            "uses_ifso_variables",
        ],
    )

def _test_interface_library_building_variables_when_generation_not_allowed_impl(env, target):
    action = _cc_library_static_library_action(env, target)
    action.argv().contains("--generate-interface-library=no")
    action.argv().contains("--interface-library-input=ignored")
    action.argv().contains("--interface-library-output=ignored")
    action.argv().contains("--interface-library-builder=ignored")

def _test_no_ifso_building_when_thin_lto_indexing(name):
    _cc_library_setup(name)

    cc_analysis_test(
        name = name,
        impl = _test_no_ifso_building_when_thin_lto_indexing_impl,
        target = name + "_lib",
        with_features = [
            "thin_lto",
            "supports_pic",
            "supports_interface_shared_libraries",
            "supports_dynamic_linker",
            "supports_start_end_lib",
            "uses_ifso_variables",
        ],
        config_settings = {
            "//command_line_option:features": ["thin_lto"],
        },
    )

def _test_no_ifso_building_when_thin_lto_indexing_impl(env, target):
    action_subject = env.expect.that_target(target).action_generating(
        "{package}/lib{name}.so-lto-final.params",
    )
    action = link_action_subject.new(action_subject.actual, action_subject.meta)
    action.argv().contains("--generate-interface-library=no")
    action.argv().contains("--interface-library-input=ignored")
    action.argv().contains("--interface-library-output=ignored")
    action.argv().contains("--interface-library-builder=ignored")

def link_build_variables_tests(name):
    test_suite(
        name = name,
        tests = [
            _test_force_pic_build_variable,
            _test_libraries_to_link_are_exported,
            _test_library_search_directories_are_exported,
            _test_link_simple_lib_name,
            _test_link_versioned_lib_name,
            _test_link_unusual_lib_name,
            _test_interface_library_building_variables_when_generation_possible,
            _test_interface_library_building_variables_when_generation_not_allowed,
            _test_no_ifso_building_when_thin_lto_indexing,
        ],
    )
