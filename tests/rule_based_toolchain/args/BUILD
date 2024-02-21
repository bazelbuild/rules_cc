load("@rules_testing//lib:util.bzl", "util")
load("//cc/toolchains:args.bzl", "cc_args")
load("//tests/rule_based_toolchain:analysis_test_suite.bzl", "analysis_test_suite")
load(":args_test.bzl", "TARGETS", "TESTS")

util.helper_target(
    cc_args,
    name = "simple",
    actions = ["//tests/rule_based_toolchain/actions:all_compile"],
    additional_files = [
        "//tests/rule_based_toolchain/testdata:file1",
        "//tests/rule_based_toolchain/testdata:multiple",
    ],
    args = [
        "--foo",
        "foo",
    ],
    env = {"BAR": "bar"},
)

analysis_test_suite(
    name = "test_suite",
    targets = TARGETS,
    tests = TESTS,
)
