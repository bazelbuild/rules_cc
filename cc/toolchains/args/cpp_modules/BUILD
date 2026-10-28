load("//cc/toolchains:args.bzl", "cc_args")
load("//cc/toolchains:feature.bzl", "cc_feature")

# The args C++20 modules need from a clang toolchain, matching
# unix_cc_toolchain_config. Bazel builds module interfaces only once the
# toolchain knows the `cpp_modules` feature and the build enables it, so
# toolchains that map tools for the C++20 module actions should list
# `:cpp_modules` in their known features and `:feature` in their enabled ones.
# compiler_input_flags marks a module interface unit as one, since `-x` only
# applies to the inputs after it.

package(default_visibility = ["//visibility:public"])

cc_feature(
    name = "cpp_modules",
    feature_name = "cpp_modules",
)

cc_feature(
    name = "feature",
    args = [
        ":modmap_file_args",
        ":module_output_args",
    ],
    feature_name = "cpp20_module_flags",
)

# The module map file names the BMI of each module a source imports.
cc_args(
    name = "modmap_file_args",
    actions = [
        "//cc/toolchains/actions:cpp_compile",
        "//cc/toolchains/actions:cpp20_module_compile",
        "//cc/toolchains/actions:cpp20_module_codegen",
    ],
    args = ["@{cpp_module_modmap_file}"],
    format = {"cpp_module_modmap_file": "//cc/toolchains/variables:cpp_module_modmap_file"},
    requires_not_none = "//cc/toolchains/variables:cpp_module_modmap_file",
    visibility = ["//visibility:private"],
)

# A module interface unit writes its BMI where Bazel declared it.
cc_args(
    name = "module_output_args",
    actions = ["//cc/toolchains/actions:cpp20_module_compile"],
    args = ["-fmodule-output={cpp_module_output_file}"],
    format = {"cpp_module_output_file": "//cc/toolchains/variables:cpp_module_output_file"},
    requires_not_none = "//cc/toolchains/variables:cpp_module_output_file",
    visibility = ["//visibility:private"],
)

filegroup(
    name = "srcs",
    srcs = ["BUILD"],
    visibility = ["//cc/toolchains/args:__pkg__"],
)
