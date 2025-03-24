load("//cc/toolchains:args.bzl", "cc_args")
load("//cc/toolchains:feature.bzl", "cc_feature")
load("//cc/toolchains:nested_args.bzl", "cc_nested_args")

cc_feature(
    name = "feature",
    args = [":external_include_paths"],
    feature_name = "external_include_paths",
    visibility = ["//visibility:public"],
)

cc_args(
    name = "external_include_paths",
    actions = ["//cc/toolchains/actions:compile_actions"],
    nested = [":search_dir_args"],
    requires_not_none = "//cc/toolchains/variables:external_include_paths",
    visibility = ["//visibility:public"],
)

cc_nested_args(
    name = "search_dir_args",
    args = [
        "-isystem",
        "{search_dir}",
    ],
    format = {
        "search_dir": "//cc/toolchains/variables:external_include_paths",
    },
    iterate_over = "//cc/toolchains/variables:external_include_paths",
)
