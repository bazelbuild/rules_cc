load("//cc/toolchains:args.bzl", "cc_args")
load("//cc/toolchains:args_list.bzl", "cc_args_list")
load("//cc/toolchains:feature.bzl", "cc_feature")

cc_feature(
    name = "feature",
    args = [":flags"],
    overrides = "//cc/toolchains/features/legacy:compiler_output_flags",
    visibility = ["//visibility:public"],
)

cc_args_list(
    name = "flags",
    args = [
        ":output_assembly_flags",
        ":output_preprocess_flags",
        ":output_flags",
        ":deps_scanner_output_env",
    ],
)

cc_args(
    name = "output_assembly_flags",
    actions = ["//cc/toolchains/actions:compile_actions"],
    args = ["-S"],
    requires_not_none = "//cc/toolchains/variables:output_assembly_file",
)

cc_args(
    name = "output_preprocess_flags",
    actions = ["//cc/toolchains/actions:compile_actions"],
    args = ["-E"],
    requires_not_none = "//cc/toolchains/variables:output_preprocess_file",
)

cc_args(
    name = "output_flags",
    actions = [
        "//cc/toolchains/actions:compile_actions",
        "//cc/toolchains/actions:cpp20_module_actions",
    ],
    args = [
        "-o",
        "{output_file}",
    ],
    format = {"output_file": "//cc/toolchains/variables:output_file"},
    requires_not_none = "//cc/toolchains/variables:output_file",
)

# The C++20 module dependency scanner writes its P1689 output to the file this
# names; the output_flags above name the scanned compile's object.
cc_args(
    name = "deps_scanner_output_env",
    actions = ["//cc/toolchains/actions:cpp_module_deps_scanning"],
    env = {"DEPS_SCANNER_OUTPUT_FILE": "{output_file}"},
    format = {"output_file": "//cc/toolchains/variables:output_file"},
    requires_not_none = "//cc/toolchains/variables:output_file",
)

filegroup(
    name = "srcs",
    srcs = ["BUILD"],
    visibility = ["//cc/toolchains/args:__pkg__"],
)
