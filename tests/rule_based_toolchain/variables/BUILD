load("//cc/toolchains/impl:variables.bzl", "cc_builtin_variables", "cc_variable", "types")
load("//tests/rule_based_toolchain:analysis_test_suite.bzl", "analysis_test_suite")
load(":variables_test.bzl", "TARGETS", "TESTS")

cc_variable(
    name = "str",
    type = types.string,
)

cc_variable(
    name = "str_list",
    type = types.list(types.string),
)

cc_variable(
    name = "str_option",
    type = types.option(types.string),
)

cc_variable(
    name = "struct",
    actions = ["//tests/rule_based_toolchain/actions:c_compile"],
    type = types.struct(
        nested_str = types.string,
        nested_str_list = types.list(types.string),
    ),
)

cc_variable(
    name = "struct_list",
    type = types.list(types.struct(
        nested_str = types.string,
        nested_str_list = types.list(types.string),
    )),
)

cc_builtin_variables(
    name = "variables",
    srcs = [
        ":str",
        ":str_list",
        ":str_option",
        ":struct",
        ":struct_list",
    ],
)

analysis_test_suite(
    name = "test_suite",
    targets = TARGETS,
    tests = TESTS,
)
