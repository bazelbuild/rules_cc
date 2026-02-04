load("//cc/toolchains:feature.bzl", "cc_feature")
load("//cc/toolchains/impl:args_for_compiler.bzl", "cc_args_for_compiler")

cc_feature(
    name = "feature",
    args = [
        ":flags",
        ":flags_windows",
    ],
    overrides = "//cc/toolchains/features/legacy:compiler_input_flags",
    visibility = ["//visibility:public"],
)

cc_args_for_compiler(
    name = "flags",
    actions = ["//cc/toolchains/actions:compile_actions"],
    args = [
        "-c",
        "{source_file}",
    ],
    exclude_compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    format = {"source_file": "//cc/toolchains/variables:source_file"},
    requires_not_none = "//cc/toolchains/variables:source_file",
)

cc_args_for_compiler(
    name = "flags_windows",
    actions = [
        "//cc/toolchains/actions:assemble",
        "//cc/toolchains/actions:preprocess_assemble",
        "//cc/toolchains/actions:c_compile",
        "//cc/toolchains/actions:linkstamp_compile",
        "//cc/toolchains/actions:cpp_compile",
        "//cc/toolchains/actions:cpp_header_parsing",
        "//cc/toolchains/actions:cpp_module_compile",
        "//cc/toolchains/actions:cpp_module_codegen",
        "//cc/toolchains/actions:cpp_module_deps_scanning",
        "//cc/toolchains/actions:cpp20_module_compile",
        "//cc/toolchains/actions:cpp20_module_codegen",
    ],
    args = [
        "/c",
        "{source_file}",
    ],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    format = {"source_file": "//cc/toolchains/variables:source_file"},
    requires_not_none = "//cc/toolchains/variables:source_file",
)
