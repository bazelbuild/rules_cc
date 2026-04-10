load("//cc/toolchains:legacy_tool.bzl", "cc_legacy_tool")
load("//tests/rule_based_toolchain:analysis_test_suite.bzl", "analysis_test_suite")
load(":legacy_tool_test.bzl", "TARGETS", "TESTS")

cc_legacy_tool(
    name = "gcov_tool",
    path = "/usr/bin/gcov",
    tool_name = "gcov",
    visibility = ["//tests/rule_based_toolchain:__subpackages__"],
)

analysis_test_suite(
    name = "test_suite",
    targets = TARGETS,
    tests = TESTS,
)
