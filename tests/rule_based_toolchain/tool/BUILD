load("@rules_testing//lib:util.bzl", "util")
load("//cc/toolchains:tool.bzl", "cc_tool")
load("//tests/rule_based_toolchain:analysis_test_suite.bzl", "analysis_test_suite")
load(":tool_test.bzl", "TARGETS", "TESTS")

util.helper_target(
    cc_tool,
    name = "tool",
    data = ["//tests/rule_based_toolchain/testdata:bin"],
    executable = "//tests/rule_based_toolchain/testdata:bin_wrapper.sh",
    execution_requirements = ["requires-mac"],
)

util.helper_target(
    cc_tool,
    name = "wrapped_tool",
    executable = "//tests/rule_based_toolchain/testdata:bin_wrapper",
)

util.helper_target(
    cc_tool,
    name = "data_with_runfiles",
    executable = "//tests/rule_based_toolchain/testdata:file1",
)

analysis_test_suite(
    name = "test_suite",
    targets = TARGETS,
    tests = TESTS,
)
