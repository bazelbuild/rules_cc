load("//cc/toolchains:args.bzl", "cc_args")
load("//cc/toolchains:feature.bzl", "cc_feature")

package(default_visibility = ["//visibility:public"])

cc_feature(
    name = "def_file",
    args = [":def_file_args"],
    feature_name = "def_file",
)

cc_args(
    name = "def_file_args",
    actions = ["//cc/toolchains/actions:link_actions"],
    args = ["{def_file_path}"],
    format = {"def_file_path": "//cc/toolchains/variables:def_file_path"},
    requires_not_none = "//cc/toolchains/variables:def_file_path",
)
