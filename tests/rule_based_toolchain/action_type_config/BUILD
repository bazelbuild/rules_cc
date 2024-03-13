load("@rules_testing//lib:util.bzl", "util")
load("//cc/toolchains:action_type_config.bzl", "cc_action_type_config")
load("//tests/rule_based_toolchain:analysis_test_suite.bzl", "analysis_test_suite")
load(":action_type_config_test.bzl", "TARGETS", "TESTS")

util.helper_target(
    cc_action_type_config,
    name = "file_map",
    action_types = ["//tests/rule_based_toolchain/actions:all_compile"],
    args = ["//tests/rule_based_toolchain/args_list"],
    data = [
        "//tests/rule_based_toolchain/testdata:multiple2",
    ],
    tools = [
        "//tests/rule_based_toolchain/testdata:bin_wrapper.sh",
        "//tests/rule_based_toolchain/tool:wrapped_tool",
    ],
)

util.helper_target(
    cc_action_type_config,
    name = "c_compile_config",
    action_types = ["//tests/rule_based_toolchain/actions:c_compile"],
    tools = [
        "//tests/rule_based_toolchain/testdata:bin_wrapper.sh",
    ],
)

util.helper_target(
    cc_action_type_config,
    name = "cpp_compile_config",
    action_types = ["//tests/rule_based_toolchain/actions:cpp_compile"],
    tools = [
        "//tests/rule_based_toolchain/testdata:bin_wrapper.sh",
    ],
)

analysis_test_suite(
    name = "test_suite",
    targets = TARGETS,
    tests = TESTS,
)
