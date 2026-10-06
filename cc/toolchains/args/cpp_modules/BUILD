load("//cc/toolchains:args.bzl", "cc_args")
load("//cc/toolchains:feature.bzl", "cc_feature")
load("//cc/toolchains:feature_set.bzl", "cc_feature_set")

# The args C++20 modules need from a clang toolchain, matching
# unix_cc_toolchain_config. Bazel builds module interfaces only once the
# toolchain knows the `cpp_modules` feature and the build enables it, so
# toolchains that map tools for the C++20 module actions should list
# `:cpp_modules` in their known features and `:feature` in their enabled ones.

package(default_visibility = ["//visibility:public"])

cc_feature(
    name = "cpp_modules",
    feature_name = "cpp_modules",
)

cc_feature_set(
    name = "feature",
    all_of = [
        ":cpp_module_modmap_file",
        ":cpp20_module_compile_flags",
    ],
)

# The module map file names the BMI of each module a source imports.
cc_feature(
    name = "cpp_module_modmap_file",
    args = [":modmap_file_args"],
    feature_name = "cpp_module_modmap_file",
)

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

# A module interface unit compiles as one, and writes its BMI where Bazel
# declared it.
cc_feature(
    name = "cpp20_module_compile_flags",
    args = [
        ":module_interface_args",
        ":module_output_args",
    ],
    feature_name = "cpp20_module_compile_flags",
)

cc_args(
    name = "module_interface_args",
    actions = ["//cc/toolchains/actions:cpp20_module_compile"],
    args = [
        "-x",
        "c++-module",
    ],
    visibility = ["//visibility:private"],
)

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
