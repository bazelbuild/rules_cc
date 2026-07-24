load("//cc:defs.bzl", "cc_library")
load(":action_command_line_test_test.bzl", "mock_toolchain_action_command_line_test")
load(":cc_binary_configured_target_tests.bzl", "cc_binary_configured_target_tests")
load(":cc_binary_thin_lto_tests.bzl", "cc_binary_thin_lto_tests")
load(":cc_common_test.bzl", "cc_common_tests")
load(":cc_fdo_env_test.bzl", "cc_fdo_env_tests")
load(":cc_import_configured_target_tests.bzl", "cc_import_configured_target_tests")
load(":cc_library_configured_target_tests.bzl", "cc_library_configured_target_tests")
load(":cc_objc_library_configured_target_tests.bzl", "cc_objc_library_configured_target_tests")
load(":cpp_modules_test.bzl", "cpp_modules_tests")
load(":debug_info_packaging_test.bzl", "debug_info_packaging_tests")
load(":link_build_variables_test.bzl", "link_build_variables_tests")

cc_library(
    name = "action_command_line_test_subject",
    testonly = True,
    srcs = ["action_command_line_test_subject.cc"],
    tags = ["manual"],
    visibility = ["//visibility:private"],
)

mock_toolchain_action_command_line_test(
    name = "action_command_line_test_test",
    expected_argv = [
        "/usr/bin/mock-gcc",
        "--default-compile-flag",
        "<flag>",
    ],
    mnemonic = "CppCompile",
    not_expected_argv = ["-ldefault-link-flag"],
    target_under_test = ":action_command_line_test_subject",
    visibility = ["//visibility:private"],
)

cc_binary_configured_target_tests(name = "cc_binary_configured_target_tests")

cc_binary_thin_lto_tests(name = "cc_binary_thin_lto_tests")

cc_common_tests(name = "cc_common_tests")

cc_import_configured_target_tests(name = "cc_import_configured_target_tests")

cc_library_configured_target_tests(name = "cc_library_configured_target_tests")

cc_objc_library_configured_target_tests(name = "cc_objc_library_configured_target_tests")

cpp_modules_tests(name = "cpp_modules_tests")

debug_info_packaging_tests(name = "debug_info_packaging_tests")

cc_fdo_env_tests(name = "cc_fdo_env_tests")

link_build_variables_tests(name = "link_build_variables_tests")
