# Features for selecting the C and C++ language standard on MSVC and clang-cl.
#
# These carry the same feature names as //cc/toolchains/args/std (so that
# `features = ["c++20"]` means the same thing regardless of compiler) but emit
# the `/std:` flag. Only the standards MSVC supports are provided; see
# standards.bzl for the mapping. They share the `c_std` / `cpp_std` mutually
# exclusive categories with the GCC/Clang variants.

load("//cc/toolchains:feature_constraint.bzl", "cc_feature_constraint")
load("//cc/toolchains:feature_set.bzl", "cc_feature_set")
load("//cc/toolchains/args/std:standards.bzl", "MSVC_CPP_STANDARDS", "MSVC_C_STANDARDS")
load("//cc/toolchains/args/std:std_feature.bzl", "cc_std_feature")

package(default_visibility = ["//visibility:public"])

[
    cc_std_feature(
        name = std,
        actions = ["//cc/toolchains/args/std:c_std_actions"],
        args = [flag],
        mutually_exclusive = ["//cc/toolchains/args/std:c_std"],
    )
    for std, flag in MSVC_C_STANDARDS.items()
]

cc_feature_set(
    name = "all_c_std_features",
    all_of = [":" + std for std in MSVC_C_STANDARDS],
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
        actions = ["//cc/toolchains/args/std:cpp_std_actions"],
        args = [flag],
        mutually_exclusive = ["//cc/toolchains/args/std:cpp_std"],
    )
    for std, flag in MSVC_CPP_STANDARDS.items()
]

cc_feature_set(
    name = "all_cpp_std_features",
    all_of = [":" + std for std in MSVC_CPP_STANDARDS],
)

# Satisfied when no C++ standard feature is enabled. Use this with
# `cc_args.requires_any_of` to supply a default C++ standard.
cc_feature_constraint(
    name = "cpp_std_unspecified",
    none_of = [":all_cpp_std_features"],
)

# Every MSVC language standard feature, for use in `cc_toolchain.known_features`.
cc_feature_set(
    name = "all_std_features",
    all_of = [
        ":all_c_std_features",
        ":all_cpp_std_features",
    ],
)

filegroup(
    name = "srcs",
    srcs = ["BUILD"],
    visibility = ["//cc/toolchains/args/std:__pkg__"],
)
