load("@rules_testing//lib:util.bzl", "util")
load("//cc/toolchains:directory_tool.bzl", "cc_directory_tool")
load("//cc/toolchains:tool.bzl", "cc_tool")
load("//tests/rule_based_toolchain:analysis_test_suite.bzl", "analysis_test_suite")
load(":tool_test.bzl", "TARGETS", "TESTS")

util.helper_target(
    cc_tool,
    name = "tool",
    src = "//tests/rule_based_toolchain/testdata:bin_wrapper.sh",
    data = ["//tests/rule_based_toolchain/testdata:bin"],
    execution_requirements = ["requires-network"],
)

util.helper_target(
    cc_tool,
    name = "wrapped_tool",
    src = "//tests/rule_based_toolchain/testdata:bin_wrapper",
    visibility = ["//tests/rule_based_toolchain:__subpackages__"],
)

cc_directory_tool(
    name = "directory_tool",
    data = ["bin"],
    directory = "//tests/rule_based_toolchain/testdata:directory",
    executable = "bin_wrapper.sh",
    execution_requirements = ["requires-network"],
)

analysis_test_suite(
    name = "test_suite",
    targets = TARGETS,
    tests = TESTS,
)
