load("//cc/toolchains:args.bzl", "cc_args")
load("//cc/toolchains:feature.bzl", "cc_feature")

package(default_visibility = ["//visibility:public"])

cc_feature(
    name = "feature",
    args = [":random_seed"],
    overrides = "//cc/toolchains/features/legacy:random_seed",
)

cc_args(
    name = "random_seed",
    actions = [
        "//cc/toolchains/actions:c_compile_actions",
        "//cc/toolchains/actions:cpp_compile_actions",
        "//cc/toolchains/actions:objc_compile",
    ],
    args = ["-frandom-seed={output_file}"],
    format = {"output_file": "//cc/toolchains/variables:output_file"},
    requires_not_none = "//cc/toolchains/variables:output_file",
)
