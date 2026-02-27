load("//cc/toolchains:nested_args.bzl", "cc_nested_args")
load("//cc/toolchains/impl:args_for_compiler.bzl", "cc_args_for_compiler")

cc_args_for_compiler(
    name = "external_include_paths",
    actions = ["//cc/toolchains/actions:compile_actions"],
    exclude_compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    nested = [":search_dir_args"],
    requires_not_none = "//cc/toolchains/variables:external_include_paths",
    visibility = ["//visibility:public"],
)

cc_args_for_compiler(
    name = "external_include_paths_windows",
    actions = [
        "//cc/toolchains/actions:preprocess_assemble",
        "//cc/toolchains/actions:linkstamp_compile",
        "//cc/toolchains/actions:c_compile",
        "//cc/toolchains/actions:cpp_compile",
        "//cc/toolchains/actions:cpp_header_parsing",
        "//cc/toolchains/actions:cpp_module_compile",
        "//cc/toolchains/actions:cpp_module_deps_scanning",
        "//cc/toolchains/actions:cpp20_module_compile",
        "//cc/toolchains/actions:clif_match",
        "//cc/toolchains/actions:objc_compile",
        "//cc/toolchains/actions:objcpp_compile",
    ],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    nested = [":search_dir_args_windows"],
    requires_not_none = "//cc/toolchains/variables:external_include_paths",
    visibility = ["//visibility:public"],
)

cc_nested_args(
    name = "search_dir_args",
    args = [
        "-isystem",
        "{search_dir}",
    ],
    format = {
        "search_dir": "//cc/toolchains/variables:external_include_paths",
    },
    iterate_over = "//cc/toolchains/variables:external_include_paths",
)

cc_nested_args(
    name = "search_dir_args_windows",
    args = [
        "/external:I{search_dir}",
    ],
    format = {
        "search_dir": "//cc/toolchains/variables:external_include_paths",
    },
    iterate_over = "//cc/toolchains/variables:external_include_paths",
)
