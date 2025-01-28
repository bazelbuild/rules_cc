load("//cc/toolchains:args.bzl", "cc_args")
load("//cc/toolchains:args_list.bzl", "cc_args_list")

cc_args_list(
    name = "strip_flags",
    args = [
        ":strip_debug",
        ":preserve_dates",
        ":output_file",
        ":input_file",
    ],
    visibility = ["//visibility:public"],
)

cc_args(
    name = "strip_debug",
    actions = ["//cc/toolchains/actions:strip"],
    args = ["-S"],
)

cc_args(
    name = "preserve_dates",
    actions = ["//cc/toolchains/actions:strip"],
    args = select({
        "@platforms//os:macos": [],
        "//conditions:default": ["-p"],
    }),
)

cc_args(
    name = "output_file",
    actions = ["//cc/toolchains/actions:strip"],
    args = [
        "-o",
        "{output_file}",
    ],
    format = {"output_file": "//cc/toolchains/variables:output_file"},
)

cc_args(
    name = "input_file",
    actions = ["//cc/toolchains/actions:strip"],
    args = ["{input_file}"],
    format = {"input_file": "//cc/toolchains/variables:input_file"},
)
