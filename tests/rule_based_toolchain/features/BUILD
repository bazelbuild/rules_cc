load("@rules_testing//lib:util.bzl", "util")
load("//cc/toolchains:args.bzl", "cc_args")
load("//cc/toolchains:feature.bzl", "cc_feature")
load("//tests/rule_based_toolchain:analysis_test_suite.bzl", "analysis_test_suite")
load(":features_test.bzl", "TARGETS", "TESTS")

util.helper_target(
    cc_args,
    name = "c_compile",
    actions = ["//tests/rule_based_toolchain/actions:c_compile"],
    additional_files = ["//tests/rule_based_toolchain/testdata:file1"],
    args = ["c"],
)

util.helper_target(
    cc_feature,
    name = "simple",
    args = [":c_compile"],
    enabled = False,
    feature_name = "feature_name",
    visibility = ["//tests/rule_based_toolchain:__subpackages__"],
)

util.helper_target(
    cc_feature,
    name = "requires",
    args = [":c_compile"],
    enabled = True,
    feature_name = "requires",
    requires_any_of = [":simple"],
)

util.helper_target(
    cc_feature,
    name = "implies",
    args = [":c_compile"],
    enabled = True,
    feature_name = "implies",
    implies = [":simple"],
)

util.helper_target(
    cc_feature,
    name = "mutual_exclusion_feature",
    args = [":c_compile"],
    enabled = True,
    feature_name = "mutual_exclusion",
    mutually_exclusive = [":simple"],
)

analysis_test_suite(
    name = "test_suite",
    targets = TARGETS,
    tests = TESTS,
)
