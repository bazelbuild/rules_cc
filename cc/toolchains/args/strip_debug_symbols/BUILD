load("//cc/toolchains:args_list.bzl", "cc_args_list")
load("//cc/toolchains:feature.bzl", "cc_feature")
load("//cc/toolchains/impl:args_for_compiler.bzl", "cc_args_for_compiler")

package(default_visibility = ["//visibility:public"])

cc_feature(
    name = "feature",
    args = [":strip_debug_symbols"],
    overrides = "//cc/toolchains/features/legacy:strip_debug_symbols",
)

cc_args_for_compiler(
    name = "strip_debug_symbols_generic",
    actions = ["//cc/toolchains/actions:link_actions"],
    args = ["-Wl,-S"],
    exclude_compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    requires_not_none = "//cc/toolchains/variables:strip_debug_symbols",
)

cc_args_list(
    name = "strip_debug_symbols",
    args = [
        "strip_debug_symbols_generic",
    ],
)
