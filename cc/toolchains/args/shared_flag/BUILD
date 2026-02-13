load("//cc/toolchains:feature.bzl", "cc_feature")
load("//cc/toolchains/impl:args_for_compiler.bzl", "cc_args_for_compiler")

package(default_visibility = ["//visibility:private"])

cc_feature(
    name = "feature",
    args = [
        ":shared_flag",
        ":shared_flag_windows",
    ],
    overrides = "//cc/toolchains/features/legacy:shared_flag",
    visibility = ["//visibility:public"],
)

cc_args_for_compiler(
    name = "shared_flag",
    actions = ["//cc/toolchains/actions:dynamic_library_link_actions"],
    args = ["-shared"],
    exclude_compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    visibility = ["//visibility:public"],
)

cc_args_for_compiler(
    name = "shared_flag_windows",
    actions = ["//cc/toolchains/actions:dynamic_library_link_actions"],
    args = ["/DLL"],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    visibility = ["//visibility:public"],
)
