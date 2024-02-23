load("@rules_testing//lib:util.bzl", "util")
load("//cc/toolchains:args.bzl", "cc_args")
load("//cc/toolchains:args_list.bzl", "cc_args_list")
load("//tests/rule_based_toolchain:analysis_test_suite.bzl", "analysis_test_suite")
load(":args_list_test.bzl", "TARGETS", "TESTS")

util.helper_target(
    cc_args,
    name = "c_compile_args",
    actions = ["//tests/rule_based_toolchain/actions:c_compile"],
    additional_files = ["//tests/rule_based_toolchain/testdata:file1"],
    args = ["c"],
)

util.helper_target(
    cc_args,
    name = "cpp_compile_args",
    actions = ["//tests/rule_based_toolchain/actions:cpp_compile"],
    additional_files = ["//tests/rule_based_toolchain/testdata:file2"],
    args = ["cpp"],
)

util.helper_target(
    cc_args,
    name = "all_compile_args",
    actions = ["//tests/rule_based_toolchain/actions:all_compile"],
    additional_files = ["//tests/rule_based_toolchain/testdata:multiple1"],
    args = ["all"],
)

util.helper_target(
    cc_args_list,
    name = "args_list",
    args = [
        ":c_compile_args",
        ":cpp_compile_args",
        ":all_compile_args",
    ],
)

analysis_test_suite(
    name = "test_suite",
    targets = TARGETS,
    tests = TESTS,
)
