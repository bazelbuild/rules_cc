load("//cc/toolchains:args.bzl", "cc_args")
load("//cc/toolchains:feature.bzl", "cc_feature")

cc_feature(
    name = "feature",
    args = [
        ":flags",
        ":module_interface_args",
        ":header_parsing_args",
    ],
    overrides = "//cc/toolchains/features/legacy:compiler_input_flags",
    visibility = ["//visibility:public"],
)

cc_args(
    name = "flags",
    actions = [
        "//cc/toolchains/actions:compile_actions_without_header_parsing",
        "//cc/toolchains/actions:cpp20_module_codegen",
        "//cc/toolchains/actions:cpp_module_deps_scanning",
    ],
    args = [
        "-c",
        "{source_file}",
    ],
    format = {"source_file": "//cc/toolchains/variables:source_file"},
    requires_not_none = "//cc/toolchains/variables:source_file",
)

# A C++20 module interface unit compiles as one whatever its extension. `-x`
# only applies to the inputs after it, so it goes right before the source.
cc_args(
    name = "module_interface_args",
    actions = ["//cc/toolchains/actions:cpp20_module_compile"],
    args = [
        "-x",
        "c++-module",
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

filegroup(
    name = "srcs",
    srcs = ["BUILD"],
    visibility = ["//cc/toolchains/args:__pkg__"],
)
