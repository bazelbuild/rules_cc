load("//cc/toolchains:feature.bzl", "cc_feature")
load("//cc/toolchains/impl:args_for_compiler.bzl", "cc_args_for_compiler")

cc_feature(
    name = "feature",
    args = [":flags"],
    overrides = "//cc/toolchains/features/legacy:library_search_directories",
    visibility = ["//visibility:public"],
)

cc_args_for_compiler(
    name = "flags",
    actions = ["//cc/toolchains/actions:link_actions"],
    args = ["-L{library_search_directories}"],
    exclude_compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    format = {"library_search_directories": "//cc/toolchains/variables:library_search_directories"},
    iterate_over = "//cc/toolchains/variables:library_search_directories",
    requires_not_none = "//cc/toolchains/variables:library_search_directories",
)
