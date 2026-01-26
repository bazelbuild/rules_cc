load("//cc/toolchains:feature.bzl", "cc_feature")
load("//cc/toolchains/impl:args_for_compiler.bzl", "cc_args_for_compiler")

package(default_visibility = ["//visibility:public"])

cc_feature(
    name = "feature",
    args = [":random_seed"],
    overrides = "//cc/toolchains/features/legacy:random_seed",
)

cc_args_for_compiler(
    name = "random_seed",
    actions = ["//cc/toolchains/actions:compile_actions"],
    args = ["-frandom-seed={output_file}"],
    exclude_compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    format = {"output_file": "//cc/toolchains/variables:output_file"},
    requires_not_none = "//cc/toolchains/variables:output_file",
)
