"""Bazel-only tests for C++ modules."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@rules_testing//lib:analysis_test.bzl", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching")
load("@rules_testing//lib:util.bzl", "util")
load("//cc:action_names.bzl", "ACTION_NAMES")
load("//cc:cc_binary.bzl", "cc_binary")
load("//cc:cc_library.bzl", "cc_library")
load("//cc:cc_test.bzl", "cc_test")
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test")

def _setup_with_features_target(name, rule_fn, suffix):
    util.empty_file(name + "/foo.cppm")
    util.helper_target(
        rule_fn,
        name = name + suffix,
        srcs = [name + "/foo.cppm"],
    )

def _test_cpp_modules_cc_library_configuration_with_features(name, **kwargs):
    _setup_with_features_target(name, cc_library, "_lib")
    cc_analysis_test(
        name = name,
        target = name + "_lib",
        impl = _test_cpp_modules_with_features_impl,
        test_features = ["cpp_modules"],
        with_action_configs = [
            ACTION_NAMES.cpp_module_deps_scanning,
            ACTION_NAMES.cpp20_module_compile,
        ],
        config_settings = {
            "//command_line_option:experimental_cpp_modules": True,
        },
        **kwargs
    )

def _test_cpp_modules_cc_binary_configuration_with_features(name, **kwargs):
    _setup_with_features_target(name, cc_binary, "_bin")
    cc_analysis_test(
        name = name,
        target = name + "_bin",
        impl = _test_cpp_modules_with_features_impl,
        test_features = ["cpp_modules"],
        with_action_configs = [
            ACTION_NAMES.cpp_module_deps_scanning,
            ACTION_NAMES.cpp20_module_compile,
        ],
        config_settings = {
            "//command_line_option:experimental_cpp_modules": True,
        },
        **kwargs
    )

def _test_cpp_modules_cc_test_configuration_with_features(name, **kwargs):
    _setup_with_features_target(name, cc_test, "_test")
    cc_analysis_test(
        name = name,
        target = name + "_test",
        impl = _test_cpp_modules_with_features_impl,
        test_features = ["cpp_modules"],
        with_action_configs = [
            ACTION_NAMES.cpp_module_deps_scanning,
            ACTION_NAMES.cpp20_module_compile,
        ],
        config_settings = {
            "//command_line_option:experimental_cpp_modules": True,
        },
        **kwargs
    )

def _test_cpp_modules_with_features_impl(env, target):
    env.expect.that_target(target).action_named("CppDepsScanning")
    env.expect.that_target(target).action_named("CppCompile")
    env.expect.that_target(target).action_named("CppAggregateDdi")
    env.expect.that_target(target).action_named("CppGenModmap")

def _test_cpp_modules_module_interface_and_source_in_srcs(name, **kwargs):
    util.empty_file(name + "/foo.cppm")
    util.empty_file(name + "/bar.cc")
    util.helper_target(
        cc_library,
        name = name + "_lib",
        srcs = [
            name + "/foo.cppm",
            name + "/bar.cc",
        ],
    )
    cc_analysis_test(
        name = name,
        target = name + "_lib",
        impl = _test_cpp_modules_module_interface_and_source_in_srcs_impl,
        test_features = ["cpp_modules"],
        with_action_configs = [
            ACTION_NAMES.cpp_module_deps_scanning,
            ACTION_NAMES.cpp20_module_compile,
        ],
        config_settings = {
            "//command_line_option:experimental_cpp_modules": True,
        },
        **kwargs
    )

def _test_cpp_modules_module_interface_and_source_in_srcs_impl(env, target):
    compiled_srcs = {}
    for action in target.actions:
        if action.mnemonic == "CppCompile":
            for input in action.inputs.to_list():
                if input.extension in ["cc", "cppm"]:
                    compiled_srcs[input.basename] = True
    env.expect.that_collection(compiled_srcs.keys()).contains_exactly(["bar.cc", "foo.cppm"])

def _test_cpp_modules_module_interface_is_instrumented(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/instrumented",
        srcs = [name + "/foo.cppm"],
    )
    cc_analysis_test(
        name = name,
        target = name + "/instrumented",
        impl = _test_cpp_modules_module_interface_is_instrumented_impl,
        test_features = ["cpp_modules"],
        with_action_configs = [
            ACTION_NAMES.cpp_module_deps_scanning,
            ACTION_NAMES.cpp20_module_compile,
        ],
        config_settings = {
            "//command_line_option:collect_code_coverage": True,
            "//command_line_option:experimental_cpp_modules": True,
            "//command_line_option:instrumentation_filter": "/instrumented$",
        },
        **kwargs
    )

def _test_cpp_modules_module_interface_is_instrumented_impl(env, target):
    env.expect.that_target(target).provider(
        InstrumentedFilesInfo,
    ).instrumented_files().contains_predicate(matching.file_basename_equals("foo.cppm"))

def _setup_duplicated_interfaces_target(name, rule_fn, suffix):
    util.empty_file(name + "/a.cppm")
    util.helper_target(
        native.filegroup,
        name = name + "_a1",
        srcs = [name + "/a.cppm"],
    )
    util.helper_target(
        native.filegroup,
        name = name + "_a2",
        srcs = [name + "/a.cppm"],
    )
    util.helper_target(
        rule_fn,
        name = name + suffix,
        srcs = [
            name + "_a1",
            name + "_a2",
        ],
    )

def _test_same_module_interfaces_file_in_cc_library_twice(name, **kwargs):
    _setup_duplicated_interfaces_target(name, cc_library, "_lib")
    cc_analysis_test(
        name = name,
        target = name + "_lib",
        impl = _test_same_module_interfaces_twice_impl,
        expect_failure = True,
        test_features = ["cpp_modules"],
        with_action_configs = [
            ACTION_NAMES.cpp_module_deps_scanning,
            ACTION_NAMES.cpp20_module_compile,
        ],
        config_settings = {
            "//command_line_option:experimental_cpp_modules": True,
        },
        **kwargs
    )

def _test_same_module_interfaces_file_in_cc_binary_twice(name, **kwargs):
    _setup_duplicated_interfaces_target(name, cc_binary, "_bin")
    cc_analysis_test(
        name = name,
        target = name + "_bin",
        impl = _test_same_module_interfaces_twice_impl,
        expect_failure = True,
        test_features = ["cpp_modules"],
        with_action_configs = [
            ACTION_NAMES.cpp_module_deps_scanning,
            ACTION_NAMES.cpp20_module_compile,
        ],
        config_settings = {
            "//command_line_option:experimental_cpp_modules": True,
        },
        **kwargs
    )

def _test_same_module_interfaces_file_in_cc_test_twice(name, **kwargs):
    _setup_duplicated_interfaces_target(name, cc_test, "_test")
    cc_analysis_test(
        name = name,
        target = name + "_test",
        impl = _test_same_module_interfaces_twice_impl,
        expect_failure = True,
        test_features = ["cpp_modules"],
        with_action_configs = [
            ACTION_NAMES.cpp_module_deps_scanning,
            ACTION_NAMES.cpp20_module_compile,
        ],
        config_settings = {
            "//command_line_option:experimental_cpp_modules": True,
        },
        **kwargs
    )

def _test_same_module_interfaces_twice_impl(env, target):
    package = target.label.package
    name = env.ctx.label.name
    expected_path = "%s/%s/a.cppm" % (package, name)
    expected_error = "file %s>' is duplicated" % expected_path
    env.expect.that_target(target).failures().contains_predicate(
        matching.contains(expected_error),
    )

def cpp_modules_tests(name, **kwargs):
    tests = []
    if bazel_features.cc.cc_common_is_in_rules_cc:
        tests.extend([
            _test_cpp_modules_cc_library_configuration_with_features,
            _test_cpp_modules_cc_binary_configuration_with_features,
            _test_cpp_modules_cc_test_configuration_with_features,
            _test_cpp_modules_module_interface_and_source_in_srcs,
            _test_cpp_modules_module_interface_is_instrumented,
            _test_same_module_interfaces_file_in_cc_library_twice,
            _test_same_module_interfaces_file_in_cc_binary_twice,
            _test_same_module_interfaces_file_in_cc_test_twice,
        ])

    test_suite(
        name = name,
        tests = tests,
        **kwargs
    )
