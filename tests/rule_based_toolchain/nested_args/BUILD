load("//cc/toolchains:nested_args.bzl", "cc_nested_args")
load("//cc/toolchains/impl:variables.bzl", "cc_variable", "types")
load("//tests/rule_based_toolchain:analysis_test_suite.bzl", "analysis_test_suite")
load("//tests/rule_based_toolchain/args:make_var_provider.bzl", "make_var_provider")
load(":nested_args_test.bzl", "TARGETS", "TESTS")

cc_variable(
    name = "foo",
    type = types.string,
)

cc_variable(
    name = "my_list",
    type = types.list(types.string),
)

make_var_provider(
    name = "make_vars",
    variables = {
        "MY_PATH": "/usr/local",
        "MY_FLAG": "-DFOO",
    },
)

cc_nested_args(
    name = "nested_with_make_vars",
    args = [
        "--path={MY_PATH}",
        "{MY_FLAG}",
    ],
    toolchains = [":make_vars"],
)

analysis_test_suite(
    name = "test_suite",
    targets = TARGETS,
    tests = TESTS,
)
