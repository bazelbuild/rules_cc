# Features for selecting the C and C++ language standard.
#
# Each feature is named after the value passed to the compiler's `-std=` flag,
# so users can write `features = ["c++20"]` on a target, or pass
# `--features=c++20` on the command line. Only one C standard and one C++
# standard may be enabled at a time; enabling two (e.g. `c++17` and `c++20`)
# is an error. The full list of names lives in standards.bzl.
#
# To use these in a toolchain, make them known (not enabled) and pick a
# default that applies when no standard has been selected explicitly:
#
# cc_args(
#     name = "default_cpp_std",
#     actions = ["@rules_cc//cc/toolchains/args/std:cpp_std_actions"],
#     args = ["-std=c++17"],
#     requires_any_of = ["@rules_cc//cc/toolchains/args/std:cpp_std_unspecified"],
# )
#
# cc_toolchain(
#     name = "my_toolchain",
#     args = [":default_cpp_std"],
#     known_features = ["@rules_cc//cc/toolchains/args/std:all_std_features"],
#     ...
# )
#
# These flags are for GCC and Clang style drivers. Toolchains wrapping MSVC or
# clang-cl should use the `/std:` equivalents in //cc/toolchains/args/std/msvc.

load("//cc/toolchains:actions.bzl", "cc_action_type_set")
load("//cc/toolchains:feature_constraint.bzl", "cc_feature_constraint")
load("//cc/toolchains:feature_set.bzl", "cc_feature_set")
load("//cc/toolchains:mutually_exclusive_category.bzl", "cc_mutually_exclusive_category")
load(":standards.bzl", "CPP_STANDARDS", "C_STANDARDS")
load(":std_feature.bzl", "cc_std_feature")

package(default_visibility = ["//visibility:public"])

# Only one C standard may be enabled at a time.
cc_mutually_exclusive_category(
    name = "c_std",
)

# Only one C++ standard may be enabled at a time.
cc_mutually_exclusive_category(
    name = "cpp_std",
)

cc_action_type_set(
    name = "c_std_actions",
    actions = ["//cc/toolchains/actions:c_compile_actions"],
)

cc_action_type_set(
    name = "cpp_std_actions",
    actions = [
        "//cc/toolchains/actions:cpp_compile_actions",
        "//cc/toolchains/actions:cpp20_module_actions",
    ],
    # The LTO backend consumes LLVM IR rather than C++ source, so a language
    # standard is meaningless there.
    excludes = ["//cc/toolchains/actions:lto_backend"],
)

[
    cc_std_feature(
        name = std,
        actions = [":c_std_actions"],
        mutually_exclusive = [":c_std"],
    )
    for std in C_STANDARDS
]

cc_feature_set(
    name = "all_c_std_features",
    all_of = [":" + std for std in C_STANDARDS],
)

# Satisfied when no C standard feature is enabled. Use this with
# `cc_args.requires_any_of` to supply a default C standard.
cc_feature_constraint(
    name = "c_std_unspecified",
    none_of = [":all_c_std_features"],
)

[
    cc_std_feature(
        name = std,
        actions = [":cpp_std_actions"],
        mutually_exclusive = [":cpp_std"],
    )
    for std in CPP_STANDARDS
]

cc_feature_set(
    name = "all_cpp_std_features",
    all_of = [":" + std for std in CPP_STANDARDS],
)

# Satisfied when no C++ standard feature is enabled. Use this with
# `cc_args.requires_any_of` to supply a default C++ standard.
cc_feature_constraint(
    name = "cpp_std_unspecified",
    none_of = [":all_cpp_std_features"],
)

# Every language standard feature, for use in `cc_toolchain.known_features`.
cc_feature_set(
    name = "all_std_features",
    all_of = [
        ":all_c_std_features",
        ":all_cpp_std_features",
    ],
)

filegroup(
    name = "srcs",
    srcs = [
        "BUILD",
        "standards.bzl",
        "std_feature.bzl",
        "//cc/toolchains/args/std/msvc:srcs",
    ],
    visibility = ["//cc/toolchains/args:__pkg__"],
)
