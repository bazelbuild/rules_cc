load("//tests/rule_based_toolchain:analysis_test_suite.bzl", "analysis_test_suite")
load(":std_test.bzl", "TARGETS", "TESTS")

# The MSVC variants share target names with the GCC/Clang variants, so alias
# them to distinct names for the test harness.
alias(
    name = "msvc_all_c_std_features",
    actual = "//cc/toolchains/args/std/msvc:all_c_std_features",
)

alias(
    name = "msvc_all_cpp_std_features",
    actual = "//cc/toolchains/args/std/msvc:all_cpp_std_features",
)

alias(
    name = "msvc_all_std_features",
    actual = "//cc/toolchains/args/std/msvc:all_std_features",
)

alias(
    name = "msvc_c_std_unspecified",
    actual = "//cc/toolchains/args/std/msvc:c_std_unspecified",
)

alias(
    name = "msvc_cpp_std_unspecified",
    actual = "//cc/toolchains/args/std/msvc:cpp_std_unspecified",
)

analysis_test_suite(
    name = "test_suite",
    targets = TARGETS,
    tests = TESTS,
)
