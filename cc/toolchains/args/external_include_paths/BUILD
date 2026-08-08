#
# To use this feature pass `--features=external_include_paths --host_features=external_include_paths`
#
# To enable this by default, add it to your `enabled_features`:
#
# enabled_features = [
#     "@rules_cc//cc/toolchains/args/external_include_paths:feature",
# ],
#

load("//cc/toolchains:args.bzl", "cc_args")
load("//cc/toolchains:feature.bzl", "cc_feature")

cc_feature(
    name = "feature",
    args = [":external_include_paths"],
    feature_name = "external_include_paths",
    visibility = ["//visibility:public"],
)

cc_args(
    name = "external_include_paths",
    actions = ["//cc/toolchains/actions:compile_actions"],
    args = [
        "-isystem",
        "{search_dir}",
    ],
    format = {"search_dir": "//cc/toolchains/variables:external_include_paths"},
    iterate_over = "//cc/toolchains/variables:external_include_paths",
    requires_not_none = "//cc/toolchains/variables:external_include_paths",
    visibility = ["//visibility:public"],
)
