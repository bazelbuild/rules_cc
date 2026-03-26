load("//cc/toolchains:args.bzl", "cc_args")
load("//cc/toolchains:feature.bzl", "cc_feature")

cc_feature(
    name = "feature",
    args = [
        ":flags",
        ":header_parsing_args",
    ],
    overrides = "//cc/toolchains/features/legacy:compiler_input_flags",
    visibility = ["//visibility:public"],
)

cc_args(
    name = "flags",
    actions = ["//cc/toolchains/actions:compile_actions_without_header_parsing"],
    args = [
        "-c",
        "{source_file}",
    ],
    format = {"source_file": "//cc/toolchains/variables:source_file"},
    requires_not_none = "//cc/toolchains/variables:source_file",
)

cc_args(
    name = "header_parsing_args",
    actions = ["//cc/toolchains/actions:cpp_header_parsing"],
    args = ["{source_file}"],
    format = {"source_file": "//cc/toolchains/variables:source_file"},
    requires_not_none = "//cc/toolchains/variables:source_file",
)
