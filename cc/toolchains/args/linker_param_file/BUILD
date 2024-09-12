load("//cc/toolchains:args.bzl", "cc_args")
load("//cc/toolchains:args_list.bzl", "cc_args_list")

package(default_visibility = ["//visibility:private"])

cc_args_list(
    name = "linker_param_file",
    args = [":use_param_file"],
    visibility = ["//visibility:public"],
)

cc_args(
    name = "use_param_file",
    actions = [
        "//cc/toolchains/actions:link_actions",
        "//cc/toolchains/actions:ar_actions",
    ],
    args = ["@{param_file}"],
    format = {"param_file": "//cc/toolchains/variables:linker_param_file"},
    requires_not_none = "//cc/toolchains/variables:linker_param_file",
)
