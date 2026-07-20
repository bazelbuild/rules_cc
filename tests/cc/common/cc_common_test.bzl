"""Tests for cc_common APIs"""

load("@bazel_features//:features.bzl", "bazel_features")
load("@rules_testing//lib:analysis_test.bzl", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching")
load("@rules_testing//lib:util.bzl", "TestingAspectInfo", "util")
load("//cc:cc_binary.bzl", "cc_binary")
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

def _no_virtual_includes_impl(env, target):
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

def _uses_virtual_includes_impl(env, target):
    subject = cc_info_subject.from_target(env, target)

    include_dirs = subject.compilation_context().include_dirs()
    include_dirs.contains_at_least_predicates(
        [matching.custom(
            "contains '_virtual_includes'",
            lambda s: "_virtual_includes" in s,
        )],
    )

def _uses_system_virtual_includes_impl(env, target):
    subject = cc_info_subject.from_target(env, target)
    virtual_includes = matching.custom(
        "contains '_virtual_includes'",
        lambda s: "_virtual_includes" in s,
    )

    subject.compilation_context().system_include_dirs().contains_at_least_predicates([
        virtual_includes,
    ])
    subject.compilation_context().external_include_dirs().contains_none_of([
        virtual_includes,
    ])

def _test_strip_include_prefix_uses_virtual_includes_by_default(name):
    """Tests that strip_include_prefix uses _virtual_includes by default (skip_virtual_includes off)."""
    util.helper_target(
        cc_library,
        name = name + "/lib",
        hdrs = ["v1/foo.h"],
        strip_include_prefix = "v1",
    )

    cc_analysis_test(
        name = name,
        impl = _uses_virtual_includes_impl,
        target = name + "/lib",
    )

def _test_strip_include_prefix_no_virtual_includes_when_enabled(name):
    """Tests that --features=skip_virtual_includes avoids _virtual_includes."""
    util.helper_target(
        cc_library,
        name = name + "/lib",
        hdrs = ["v1/foo.h"],
        strip_include_prefix = "v1",
    )

    cc_analysis_test(
        name = name,
        impl = _no_virtual_includes_impl,
        target = name + "/lib",
        test_features = ["skip_virtual_includes"],
    )

def _test_strip_include_prefix_with_include_prefix_uses_virtual_includes(name):
    """Tests that strip_include_prefix with include_prefix still uses _virtual_includes even when skip is on."""
    util.helper_target(
        cc_library,
        name = name + "/lib",
        hdrs = ["v1/foo.h"],
        strip_include_prefix = "v1",
        include_prefix = "mylib",
    )

    cc_analysis_test(
        name = name,
        impl = _uses_virtual_includes_impl,
        target = name + "/lib",
        test_features = ["skip_virtual_includes"],
    )

def _test_strip_include_prefix_for_public_headers_uses_system_include_paths(name):
    util.helper_target(
        cc_library,
        name = name + "/lib",
        hdrs = ["v1/foo.h"],
        strip_include_prefix = "v1",
    )

    cc_analysis_test(
        name = name,
        impl = _uses_system_virtual_includes_impl,
        target = name + "/lib",
        config_settings = {
            "//command_line_option:features": ["system_include_paths"],
        },
    )

def _test_strip_include_prefix_for_textual_headers_uses_system_include_paths(name):
    util.helper_target(
        cc_library,
        name = name + "/lib",
        strip_include_prefix = "v1",
        textual_hdrs = ["v1/foo.h"],
    )

    cc_analysis_test(
        name = name,
        impl = _uses_system_virtual_includes_impl,
        target = name + "/lib",
        config_settings = {
            "//command_line_option:features": ["system_include_paths"],
        },
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
        test_features = ["skip_virtual_includes"],
    )

def _test_strip_include_prefix_error_not_under_prefix_impl(env, target):
    env.expect.that_target(target).failures().contains_predicate(
        matching.custom(
            "contains 'is not under the specified strip prefix'",
            lambda s: "is not under the specified strip prefix" in s,
        ),
    )

def _test_empty_library(name):
    util.helper_target(
        cc_library,
        name = name + "/emptylib",
    )

    cc_analysis_test(
        name = name,
        impl = _test_empty_library_impl,
        target = name + "/emptylib",
    )

def _test_empty_library_impl(env, target):
    # We create .a for empty libraries, for simplicity (in Blaze).
    # But we avoid creating .so files for empty libraries,
    # because those have a potentially significant run-time startup cost.
    # TODO(b/308434150): Adapt above comment and the verifiation below now that
    # b/308434150 is fixes - IIUC.
    linker_inputs = target[CcInfo].linking_context.linker_inputs.to_list()
    for input in linker_inputs:
        for lib in input.libraries:
            if lib.dynamic_library != None:
                env.expect.meta.add_failure(
                    "expected no dynamic library for empty library at runtime",
                    "actual: {}".format(lib.dynamic_library.short_path),
                )

def _test_copts(name):
    util.helper_target(
        cc_library,
        name = name + "/c_lib",
        srcs = ["foo.cc"],
        copts = [
            "-Wmy-warning",
            "-frun-faster",
        ],
    )

    cc_analysis_test(
        name = name,
        impl = _test_copts_impl,
        target = name + "/c_lib",
    )

def _test_copts_impl(env, target):
    files_to_compile = target[OutputGroupInfo].compilation_outputs.to_list()
    env.expect.that_collection(files_to_compile).has_size(1)
    compile_action = env.expect.that_target(target).action_generating(files_to_compile[0].short_path)
    compile_action.argv().contains_at_least([
        "-Wmy-warning",
        "-frun-faster",
    ])

def _test_copts_tokenization(name):
    util.helper_target(
        cc_library,
        name = name + "/c_lib",
        srcs = ["foo.cc"],
        copts = ["-Wmy-warning -frun-faster"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_copts_tokenization_impl,
        target = name + "/c_lib",
    )

def _test_copts_tokenization_impl(env, target):
    files_to_compile = target[OutputGroupInfo].compilation_outputs.to_list()
    env.expect.that_collection(files_to_compile).has_size(1)
    compile_action = env.expect.that_target(target).action_generating(files_to_compile[0].short_path)
    compile_action.argv().contains_at_least([
        "-Wmy-warning",
        "-frun-faster",
    ])

def _test_copts_no_tokenization(name):
    util.helper_target(
        cc_library,
        name = name + "/c_lib",
        srcs = ["foo.cc"],
        copts = ["-Wmy-warning -frun-faster"],
        features = ["no_copts_tokenization"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_copts_no_tokenization_impl,
        target = name + "/c_lib",
    )

def _test_copts_no_tokenization_impl(env, target):
    files_to_compile = target[OutputGroupInfo].compilation_outputs.to_list()
    env.expect.that_collection(files_to_compile).has_size(1)
    compile_action = env.expect.that_target(target).action_generating(files_to_compile[0].short_path)
    compile_action.argv().contains("-Wmy-warning -frun-faster")

def _test_isolated_defines(name):
    util.helper_target(
        cc_library,
        name = name + "/defineslib",
        srcs = ["defines.cc"],
        defines = ["FOO", "BAR"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_isolated_defines_impl,
        target = name + "/defineslib",
    )

def _test_isolated_defines_impl(env, target):
    cc_info_subject.from_target(env, target).compilation_context().defines().contains_exactly([
        "FOO",
        "BAR",
    ]).in_order()

def _test_expanded_defines_against_deps(name):
    util.helper_target(
        cc_library,
        name = name + "/foo",
        srcs = ["foo.cc"],
    )
    util.helper_target(
        cc_library,
        name = name + "/expand_deps",
        srcs = ["defines.cc"],
        deps = [":" + name + "/foo"],
        defines = ["FOO=$(location :" + name + "/foo)"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_expanded_defines_against_deps_impl,
        target = name + "/expand_deps",
    )

def _test_expanded_defines_against_deps_impl(env, target):
    bin_path = target[TestingAspectInfo].bin_path
    package = target.label.package
    parts = target.label.name.split("/")
    test_name = parts[0]

    expected = "FOO={bin_path}/{package}/{test_name}/libfoo.a".format(
        bin_path = bin_path,
        package = package,
        test_name = test_name,
    )
    cc_info_subject.from_target(env, target).compilation_context().defines().contains_exactly([expected])

def _test_expanded_defines_against_srcs(name):
    util.helper_target(
        cc_library,
        name = name + "/expand_srcs",
        srcs = ["defines.cc"],
        defines = ["FOO=$(location defines.cc)"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_expanded_defines_against_srcs_impl,
        target = name + "/expand_srcs",
    )

def _test_expanded_defines_against_srcs_impl(env, target):
    package = target.label.package
    expected = "FOO={package}/defines.cc".format(package = package)
    cc_info_subject.from_target(env, target).compilation_context().defines().contains_exactly([expected])

def _test_expanded_defines_against_data(name):
    util.helper_target(
        native.filegroup,
        name = name + "/data",
        srcs = ["data_file.txt"],
    )
    util.helper_target(
        cc_library,
        name = name + "/expand_srcs",
        srcs = ["defines.cc"],
        data = [":" + name + "/data"],
        defines = ["FOO=$(location :" + name + "/data)"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_expanded_defines_against_data_impl,
        target = name + "/expand_srcs",
    )

def _test_expanded_defines_against_data_impl(env, target):
    package = target.label.package
    expected = "FOO={package}/data_file.txt".format(package = package)
    cc_info_subject.from_target(env, target).compilation_context().defines().contains_exactly([expected])

def _test_expanded_defines_duplicate_targets(name):
    util.helper_target(
        cc_library,
        name = name + "/a",
        srcs = ["foo.cc"],
    )
    util.helper_target(
        cc_library,
        name = name + "/expand_srcs",
        srcs = ["defines.cc"],
        data = [":" + name + "/a"],
        deps = [":" + name + "/a"],
        defines = ["FOO=$(location :" + name + "/a)"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_expanded_defines_duplicate_targets_impl,
        target = name + "/expand_srcs",
    )

def _test_expanded_defines_duplicate_targets_impl(env, target):
    bin_path = target[TestingAspectInfo].bin_path
    package = target.label.package
    parts = target.label.name.split("/")
    test_name = parts[0]

    expected = "FOO={bin_path}/{package}/{test_name}/liba.a".format(
        bin_path = bin_path,
        package = package,
        test_name = test_name,
    )
    cc_info_subject.from_target(env, target).compilation_context().defines().contains_exactly([expected])

def _test_start_end_lib(name):
    util.helper_target(
        cc_library,
        name = name + "/lib",
        srcs = ["lib.c"],
    )
    util.helper_target(
        cc_binary,
        name = name + "/bin",
        srcs = ["bin.c"],
        deps = [":" + name + "/lib"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_start_end_lib_impl,
        target = name + "/bin",
        with_features = ["supports_start_end_lib"],
        config_settings = {
            "//command_line_option:start_end_lib": True,
        },
    )

def _test_start_end_lib_impl(env, target):
    executable = target[DefaultInfo].files_to_run.executable
    link_action = env.expect.that_target(target).action_generating(executable.short_path)
    link_action.inputs().not_contains_predicate(matching.file_extension_in(["a", "lib"]))

def _test_temps_with_different_extensions(name):
    util.helper_target(
        cc_library,
        name = name + "/ananas",
        srcs = [
            "1.c",
            "2.cc",
            "3.cpp",
            "4.S",
            "5.h",
            "6.hpp",
            "7.inc",
            "8.inl",
            "9.tlh",
            "A.tli",
        ],
    )

    cc_analysis_test(
        name = name,
        impl = _test_temps_with_different_extensions_impl,
        target = name + "/ananas",
        with_features = ["supports_pic"],
        config_settings = {
            "//command_line_option:save_temps": True,
        },
    )

def _test_temps_with_different_extensions_impl(env, target):
    temps = target[OutputGroupInfo].temp_files_INTERNAL_.to_list()
    env.expect.that_collection(temps).transform(
        desc = "basenames",
        map_each = lambda f: f.basename,
    ).contains_exactly([
        "1.pic.i",
        "1.pic.s",
        "2.pic.ii",
        "2.pic.s",
        "3.pic.ii",
        "3.pic.s",
    ])

def _test_temps_for_cc_with_pic(name):
    util.helper_target(
        cc_library,
        name = name + "/foo",
        srcs = ["foo.cc"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_temps_for_cc_with_pic_impl,
        target = name + "/foo",
        with_features = ["supports_pic"],
        config_settings = {
            "//command_line_option:save_temps": True,
        },
    )

def _test_temps_for_cc_with_pic_impl(env, target):
    temps = target[OutputGroupInfo].temp_files_INTERNAL_.to_list()
    env.expect.that_collection(temps).transform(
        desc = "basenames",
        map_each = lambda f: f.basename,
    ).contains_exactly([
        "foo.pic.ii",
        "foo.pic.s",
    ])

def _test_temps_for_cc_without_pic(name):
    util.helper_target(
        cc_library,
        name = name + "/foo",
        srcs = ["foo.cc"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_temps_for_cc_without_pic_impl,
        target = name + "/foo",
        config_settings = {
            "//command_line_option:save_temps": True,
        },
    )

def _test_temps_for_cc_without_pic_impl(env, target):
    temps = target[OutputGroupInfo].temp_files_INTERNAL_.to_list()
    env.expect.that_collection(temps).transform(
        desc = "basenames",
        map_each = lambda f: f.basename,
    ).contains_exactly([
        "foo.ii",
        "foo.s",
    ])

def _test_temps_for_c_with_pic(name):
    util.helper_target(
        cc_library,
        name = name + "/csrc",
        srcs = ["foo.c"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_temps_for_c_with_pic_impl,
        target = name + "/csrc",
        with_features = ["supports_pic"],
        config_settings = {
            "//command_line_option:save_temps": True,
        },
    )

def _test_temps_for_c_with_pic_impl(env, target):
    temps = target[OutputGroupInfo].temp_files_INTERNAL_.to_list()
    env.expect.that_collection(temps).transform(
        desc = "basenames",
        map_each = lambda f: f.basename,
    ).contains_exactly([
        "foo.pic.i",
        "foo.pic.s",
    ])

def _test_temps_for_c_without_pic(name):
    util.helper_target(
        cc_library,
        name = name + "/csrc",
        srcs = ["foo.c"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_temps_for_c_without_pic_impl,
        target = name + "/csrc",
        config_settings = {
            "//command_line_option:save_temps": True,
        },
    )

def _test_temps_for_c_without_pic_impl(env, target):
    temps = target[OutputGroupInfo].temp_files_INTERNAL_.to_list()
    env.expect.that_collection(temps).transform(
        desc = "basenames",
        map_each = lambda f: f.basename,
    ).contains_exactly([
        "foo.i",
        "foo.s",
    ])

def _test_library_in_hdrs(name):
    util.helper_target(
        cc_library,
        name = name + "/b",
        srcs = ["b.cc"],
    )
    util.helper_target(
        cc_library,
        name = name + "/a",
        srcs = ["a.cc"],
        hdrs = [name + "/b"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_library_in_hdrs_impl,
        target = name + "/a",
    )

def _test_library_in_hdrs_impl(env, target):
    env.expect.that_target(target).failures().contains_exactly([])

def _test_alwayslink_yields_lo(name):
    util.helper_target(
        cc_library,
        name = name + "/always_link",
        alwayslink = True,
        srcs = ["always_link.cc"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_alwayslink_yields_lo_impl,
        target = name + "/always_link",
    )

def _test_alwayslink_yields_lo_impl(env, target):
    files = [f.basename for f in target[DefaultInfo].files.to_list()]
    env.expect.that_collection(files).contains("libalways_link.lo")

def cc_common_tests(name):
    tests = [
        _test_same_cc_file_twice,
        _test_same_header_file_twice,
        _test_isolated_includes,
        _test_empty_library,
        _test_copts,
        _test_copts_tokenization,
        _test_copts_no_tokenization,
        _test_isolated_defines,
        _test_expanded_defines_against_deps,
        _test_expanded_defines_against_srcs,
        _test_expanded_defines_against_data,
        _test_expanded_defines_duplicate_targets,
        _test_start_end_lib,
        _test_temps_with_different_extensions,
        _test_temps_for_cc_with_pic,
        _test_temps_for_cc_without_pic,
        _test_temps_for_c_with_pic,
        _test_temps_for_c_without_pic,
        _test_library_in_hdrs,
        _test_alwayslink_yields_lo,
    ]
    if bazel_features.cc.cc_common_is_in_rules_cc:
        tests.extend([
            _test_strip_include_prefix_uses_virtual_includes_by_default,
            _test_strip_include_prefix_no_virtual_includes_when_enabled,
            _test_strip_include_prefix_with_include_prefix_uses_virtual_includes,
            _test_strip_include_prefix_for_public_headers_uses_system_include_paths,
            _test_strip_include_prefix_for_textual_headers_uses_system_include_paths,
            _test_strip_include_prefix_error_not_under_prefix,
        ])
    test_suite(
        name = name,
        tests = tests,
    )
