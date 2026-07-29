"""Tests for link build variables."""

load("@rules_testing//lib:analysis_test.bzl", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching")
load("@rules_testing//lib:util.bzl", "util")
load("//cc:cc_binary.bzl", "cc_binary")
load("//cc:cc_library.bzl", "cc_library")
load("//cc:cc_test.bzl", "cc_test")
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test")
load("//tests/cc/testutil:link_action_subject.bzl", "link_action_subject")

def _cc_library_setup(name):
    util.helper_target(
        cc_library,
        name = name + "_lib",
        srcs = ["a.cc"],
    )

def _cc_binary_setup(name):
    util.helper_target(
        cc_binary,
        name = name + "_bin",
        srcs = ["a.cc"],
    )

def _cc_library_nodeps_dynamic_library_action(env, target):
    action_subject = env.expect.that_target(target).action_generating("{package}/lib{name}.so")
    return link_action_subject.new(action_subject.actual, action_subject.meta)

def _cc_library_static_library_action(env, target):
    action_subject = env.expect.that_target(target).action_generating("{package}/lib{name}.a")
    return link_action_subject.new(action_subject.actual, action_subject.meta)

def _test_force_pic_build_variable(name):
    _cc_binary_setup(name)

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

def _test_output_execpath(name):
    _cc_library_setup(name)
    cc_analysis_test(
        name = name,
        impl = _test_output_execpath_impl,
        target = name + "_lib",
        with_features = [
            "supports_dynamic_linker",
            "uses_output_execpath",
        ],
    )

def _test_output_execpath_impl(env, target):
    action = _cc_library_nodeps_dynamic_library_action(env, target)
    action.argv().contains_predicate(
        matching.custom(
            "ends with libfoo.so",
            lambda s: s.startswith("--output-execpath=") and s.endswith("lib" + target.label.name + ".so"),
        ),
    )

def _test_output_execpath_is_not_exposed_when_thin_lto_indexing(name):
    _cc_library_setup(name)
    cc_analysis_test(
        name = name,
        impl = _test_output_execpath_is_not_exposed_when_thin_lto_indexing_impl,
        target = name + "_lib",
        with_features = [
            "thin_lto",
            "supports_pic",
            "supports_interface_shared_libraries",
            "supports_dynamic_linker",
            "supports_start_end_lib",
            "uses_output_execpath",
        ],
        config_settings = {
            "//command_line_option:features": ["thin_lto"],
        },
    )

def _test_output_execpath_is_not_exposed_when_thin_lto_indexing_impl(env, target):
    # TODO(b/525692821): Consider using build graph traversal once available to find the LTO backend action.
    action_subject = env.expect.that_target(target).action_generating(
        "{package}/lib{name}.so-lto-final.params",
    )
    action = link_action_subject.new(action_subject.actual, action_subject.meta)
    action.argv().not_contains_predicate(
        matching.custom(
            "starts with --output-execpath=",
            lambda s: s.startswith("--output-execpath="),
        ),
    )

def _test_is_cc_test_link_action_build_variable_for_test(name):
    util.helper_target(
        cc_test,
        name = name + "_test_target",
        srcs = ["a.cc"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_is_cc_test_link_action_build_variable_test_impl,
        target = name + "_test_target",
        with_features = ["uses_is_cc_test"],
    )

def _test_is_cc_test_link_action_build_variable_test_impl(env, target):
    action = link_action_subject.from_target(env, target)
    action.argv().contains("--linkopt-is-cc-test")

def _test_is_cc_test_link_action_build_variable_for_binary(name):
    _cc_binary_setup(name)
    cc_analysis_test(
        name = name,
        impl = _test_is_cc_test_link_action_build_variable_bin_impl,
        target = name + "_bin",
        with_features = ["uses_is_cc_test"],
    )

def _test_is_cc_test_link_action_build_variable_bin_impl(env, target):
    action = link_action_subject.from_target(env, target)
    action.argv().contains("--linkopt-is-not-cc-test")

def _strip_test_present_impl(env, target):
    action = link_action_subject.from_target(env, target)
    action.argv().contains("--strip-debug-symbols")

def _strip_test_absent_impl(env, target):
    action = link_action_subject.from_target(env, target)
    action.argv().not_contains("--strip-debug-symbols")

def _strip_test_helper(name, strip, mode, should_have_strip):
    _cc_binary_setup(name)
    impl = _strip_test_present_impl if should_have_strip else _strip_test_absent_impl
    cc_analysis_test(
        name = name,
        impl = impl,
        target = name + "_bin",
        with_features = ["uses_strip_debug_symbols"],
        config_settings = {
            "//command_line_option:strip": strip,
            "//command_line_option:compilation_mode": mode,
        },
    )

def _test_strip_always_opt(name):
    _strip_test_helper(name, "always", "opt", True)

def _test_strip_always_fastbuild(name):
    _strip_test_helper(name, "always", "fastbuild", True)

def _test_strip_always_dbg(name):
    _strip_test_helper(name, "always", "dbg", True)

def _test_strip_sometimes_opt(name):
    _strip_test_helper(name, "sometimes", "opt", False)

def _test_strip_sometimes_fastbuild(name):
    _strip_test_helper(name, "sometimes", "fastbuild", True)

def _test_strip_sometimes_dbg(name):
    _strip_test_helper(name, "sometimes", "dbg", False)

def _test_strip_never_opt(name):
    _strip_test_helper(name, "never", "opt", False)

def _test_strip_never_fastbuild(name):
    _strip_test_helper(name, "never", "fastbuild", False)

def _test_strip_never_dbg(name):
    _strip_test_helper(name, "never", "dbg", False)

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
            _test_output_execpath,
            _test_output_execpath_is_not_exposed_when_thin_lto_indexing,
            _test_is_cc_test_link_action_build_variable_for_test,
            _test_is_cc_test_link_action_build_variable_for_binary,
            _test_strip_always_opt,
            _test_strip_always_fastbuild,
            _test_strip_always_dbg,
            _test_strip_sometimes_opt,
            _test_strip_sometimes_fastbuild,
            _test_strip_sometimes_dbg,
            _test_strip_never_opt,
            _test_strip_never_fastbuild,
            _test_strip_never_dbg,
        ],
    )
