load("//cc/toolchains:args_list.bzl", "cc_args_list")
load("//cc/toolchains:feature.bzl", "cc_feature")
load("//cc/toolchains:nested_args.bzl", "cc_nested_args")
load("//cc/toolchains/impl:args_for_compiler.bzl", "cc_args_for_compiler")

cc_feature(
    name = "feature",
    args = [":flags"],
    overrides = "//cc/toolchains/features/legacy:compiler_output_flags",
    visibility = ["//visibility:public"],
)

cc_args_list(
    name = "flags",
    args = [
        ":output_assembly_flags",
        ":output_preprocess_flags",
        ":output_flags",
        ":windows_output_preprocess_flags",
        ":windows_output_assembly_flags",
        ":windows_output_object_flags",
        ":windows_output_object_flags_preprocess_assemble",
        ":windows_output_object_flags_asm",
    ],
)

cc_nested_args(
    name = "windows_output_object_file_no_preprocess",
    nested = [":windows_output_object_file_no_preprocess_or_assembly"],
    requires_none = "//cc/toolchains/variables:output_preprocess_file",
)

cc_nested_args(
    name = "windows_output_object_file_no_preprocess_or_assembly",
    args = ["/Fo{output_file}"],
    format = {"output_file": "//cc/toolchains/variables:output_file"},
    requires_none = "//cc/toolchains/variables:output_assembly_file",
)

cc_nested_args(
    name = "windows_output_object_file_asm_no_preprocess",
    nested = [":windows_output_object_file_asm_no_preprocess_or_assembly"],
    requires_none = "//cc/toolchains/variables:output_preprocess_file",
)

cc_nested_args(
    name = "windows_output_object_file_asm_no_preprocess_or_assembly",
    args = [
        "/Fo{output_file}",
        "/Zi",
    ],
    format = {"output_file": "//cc/toolchains/variables:output_file"},
    requires_none = "//cc/toolchains/variables:output_assembly_file",
)

cc_args_for_compiler(
    name = "output_assembly_flags",
    actions = ["//cc/toolchains/actions:compile_actions"],
    args = ["-S"],
    exclude_compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    requires_not_none = "//cc/toolchains/variables:output_assembly_file",
)

cc_args_for_compiler(
    name = "output_preprocess_flags",
    actions = ["//cc/toolchains/actions:compile_actions"],
    args = ["-E"],
    exclude_compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    requires_not_none = "//cc/toolchains/variables:output_preprocess_file",
)

cc_args_for_compiler(
    name = "output_flags",
    actions = ["//cc/toolchains/actions:compile_actions"],
    args = [
        "-o",
        "{output_file}",
    ],
    exclude_compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    format = {"output_file": "//cc/toolchains/variables:output_file"},
    requires_not_none = "//cc/toolchains/variables:output_file",
)

cc_args_for_compiler(
    name = "windows_output_preprocess_flags",
    actions = [
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
        "/P",
        "/Fi{output_file}",
    ],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    format = {"output_file": "//cc/toolchains/variables:output_preprocess_file"},
    requires_not_none = "//cc/toolchains/variables:output_preprocess_file",
)

cc_args_for_compiler(
    name = "windows_output_assembly_flags",
    actions = [
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
        "/Fa{output_file}",
    ],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    format = {"output_file": "//cc/toolchains/variables:output_assembly_file"},
    requires_not_none = "//cc/toolchains/variables:output_assembly_file",
)

cc_args_for_compiler(
    name = "windows_output_object_flags",
    actions = [
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
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    nested = [":windows_output_object_file_no_preprocess"],
    requires_not_none = "//cc/toolchains/variables:output_file",
)

cc_args_for_compiler(
    name = "windows_output_object_flags_preprocess_assemble",
    actions = ["//cc/toolchains/actions:preprocess_assemble"],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    nested = [":windows_output_object_file_no_preprocess"],
    requires_not_none = "//cc/toolchains/variables:output_file",
)

cc_args_for_compiler(
    name = "windows_output_object_flags_asm",
    actions = ["//cc/toolchains/actions:assemble"],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    nested = [":windows_output_object_file_asm_no_preprocess"],
    requires_not_none = "//cc/toolchains/variables:output_file",
)
