load("//cc/toolchains:args.bzl", "cc_args")
load("//cc/toolchains:args_list.bzl", "cc_args_list")
load("//cc/toolchains:feature.bzl", "cc_feature")
load("//cc/toolchains:feature_constraint.bzl", "cc_feature_constraint")
load("//cc/toolchains:mutually_exclusive_category.bzl", "cc_mutually_exclusive_category")
load("//cc/toolchains:nested_args.bzl", "cc_nested_args")
load("//cc/toolchains/impl:args_for_compiler.bzl", "cc_args_for_compiler")

package(default_visibility = ["//visibility:public"])

cc_feature(
    name = "def_file_feature",
    args = [":def_file_flags"],
    feature_name = "def_file",
)

cc_args_for_compiler(
    name = "def_file_flags",
    actions = [
        "//cc/toolchains/actions:cpp_link_executable",
        "//cc/toolchains/actions:cpp_link_dynamic_library",
        "//cc/toolchains/actions:cpp_link_nodeps_dynamic_library",
    ],
    args = [
        "/DEF:{def_file_path}",
        "/ignore:4070",
    ],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    format = {"def_file_path": "//cc/toolchains/variables:def_file_path"},
    requires_not_none = "//cc/toolchains/variables:def_file_path",
)

cc_feature(
    name = "parse_showincludes_feature",
    args = [
        ":parse_showincludes_flags",
        ":parse_showincludes_env",
    ],
    feature_name = "parse_showincludes",
)

cc_args_for_compiler(
    name = "parse_showincludes_flags",
    actions = [
        "//cc/toolchains/actions:preprocess_assemble",
        "//cc/toolchains/actions:c_compile",
        "//cc/toolchains/actions:linkstamp_compile",
        "//cc/toolchains/actions:cpp_compile",
        "//cc/toolchains/actions:cpp_module_compile",
        "//cc/toolchains/actions:cpp_header_parsing",
        "//cc/toolchains/actions:cpp_module_deps_scanning",
        "//cc/toolchains/actions:cpp20_module_compile",
    ],
    args = ["/showIncludes"],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
)

cc_args_for_compiler(
    name = "parse_showincludes_env",
    actions = [
        "//cc/toolchains/actions:preprocess_assemble",
        "//cc/toolchains/actions:c_compile",
        "//cc/toolchains/actions:linkstamp_compile",
        "//cc/toolchains/actions:cpp_compile",
        "//cc/toolchains/actions:cpp_module_compile",
        "//cc/toolchains/actions:cpp_header_parsing",
    ],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    env = {"VSLANG": "1033"},
)

cc_feature(
    name = "default_compile_flags_feature",
    args = [":default_compile_flags"],
    overrides = "//cc/toolchains/features/legacy:default_compile_flags",
)

cc_args_for_compiler(
    name = "default_compile_flags",
    actions = [
        "//cc/toolchains/actions:assemble",
        "//cc/toolchains/actions:preprocess_assemble",
        "//cc/toolchains/actions:linkstamp_compile",
        "//cc/toolchains/actions:c_compile",
        "//cc/toolchains/actions:cpp_compile",
        "//cc/toolchains/actions:cpp_header_parsing",
        "//cc/toolchains/actions:cpp_module_compile",
        "//cc/toolchains/actions:cpp_module_codegen",
        "//cc/toolchains/actions:cpp_module_deps_scanning",
        "//cc/toolchains/actions:cpp20_module_compile",
        "//cc/toolchains/actions:cpp20_module_codegen",
        "//cc/toolchains/actions:lto_backend",
        "//cc/toolchains/actions:clif_match",
    ],
    args = [
        "/DNOMINMAX",
        "/D_CRT_SECURE_NO_DEPRECATE",
        "/D_CRT_SECURE_NO_WARNINGS",
        # TODO: Add BAZEL_WIN32_WINNT override.
        "/D_WIN32_WINNT=0x0601",
        "/bigobj",
        "/Zm500",
        "/EHsc",
        "/wd4351",
        "/wd4291",
        "/wd4250",
        "/wd4996",
    ],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
)

cc_feature(
    name = "default_cpp_std_feature",
    args = [":default_cpp_std_flags"],
    feature_name = "default_cpp_std",
)

cc_args_for_compiler(
    name = "default_cpp_std_flags",
    actions = [
        "//cc/toolchains/actions:cpp_compile",
        "//cc/toolchains/actions:linkstamp_compile",
        "//cc/toolchains/actions:cpp_header_parsing",
        "//cc/toolchains/actions:cpp_module_compile",
        "//cc/toolchains/actions:cpp_module_codegen",
        "//cc/toolchains/actions:cpp_module_deps_scanning",
        "//cc/toolchains/actions:cpp20_module_compile",
        "//cc/toolchains/actions:cpp20_module_codegen",
        "//cc/toolchains/actions:clif_match",
    ],
    args = ["/std:c++17"],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
)

cc_feature(
    name = "cpp20_module_compile_flags_feature",
    args = [
        ":cpp20_module_compile_flags",
        ":cpp20_module_output_flags",
    ],
    feature_name = "cpp20_module_compile_flags",
)

cc_args_for_compiler(
    name = "cpp20_module_compile_flags",
    actions = ["//cc/toolchains/actions:cpp20_module_compile"],
    args = [
        "/TP",
        "/interface",
    ],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
)

cc_args_for_compiler(
    name = "cpp20_module_output_flags",
    actions = ["//cc/toolchains/actions:cpp20_module_compile"],
    args = ["/ifcOutput{cpp_module_output_file}"],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    format = {"cpp_module_output_file": "//cc/toolchains/variables:cpp_module_output_file"},
    requires_not_none = "//cc/toolchains/variables:cpp_module_output_file",
)

cc_feature(
    name = "determinism_feature",
    args = [
        ":determinism_flags",
        ":determinism_flags_clang_cl",
    ],
    feature_name = "determinism",
)

cc_args_for_compiler(
    name = "determinism_flags",
    actions = [
        "//cc/toolchains/actions:c_compile",
        "//cc/toolchains/actions:cpp_compile",
    ],
    args = [
        "/wd4117",
        "-D__DATE__=\"redacted\"",
        "-D__TIMESTAMP__=\"redacted\"",
        "-D__TIME__=\"redacted\"",
    ],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
)

cc_args_for_compiler(
    name = "determinism_flags_clang_cl",
    actions = [
        "//cc/toolchains/actions:c_compile",
        "//cc/toolchains/actions:cpp_compile",
    ],
    args = ["-Wno-builtin-macro-redefined"],
    compilers = ["clang-cl"],
)

cc_feature(
    name = "nologo_feature",
    args = [":nologo_flags"],
    feature_name = "nologo",
)

cc_args_for_compiler(
    name = "nologo_flags",
    actions = [
        "//cc/toolchains/actions:c_compile",
        "//cc/toolchains/actions:linkstamp_compile",
        "//cc/toolchains/actions:cpp_compile",
        "//cc/toolchains/actions:cpp_module_compile",
        "//cc/toolchains/actions:cpp_module_codegen",
        "//cc/toolchains/actions:cpp_header_parsing",
        "//cc/toolchains/actions:cpp_module_deps_scanning",
        "//cc/toolchains/actions:cpp20_module_compile",
        "//cc/toolchains/actions:cpp20_module_codegen",
        "//cc/toolchains/actions:assemble",
        "//cc/toolchains/actions:preprocess_assemble",
        "//cc/toolchains/actions:cpp_link_executable",
        "//cc/toolchains/actions:cpp_link_dynamic_library",
        "//cc/toolchains/actions:cpp_link_nodeps_dynamic_library",
        "//cc/toolchains/actions:cpp_link_static_library",
    ],
    args = ["/nologo"],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
)

cc_feature(
    name = "remove_unreferenced_code_feature",
    args = [":remove_unreferenced_code_flags"],
    feature_name = "remove_unreferenced_code",
)

cc_args_for_compiler(
    name = "remove_unreferenced_code_flags",
    actions = [
        "//cc/toolchains/actions:c_compile",
        "//cc/toolchains/actions:cpp_compile",
    ],
    args = ["/Zc:inline"],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
)

cc_feature(
    name = "ignore_noisy_warnings_feature",
    args = [":ignore_noisy_warnings_flags"],
    feature_name = "ignore_noisy_warnings",
)

cc_args_for_compiler(
    name = "ignore_noisy_warnings_flags",
    actions = ["//cc/toolchains/actions:cpp_link_static_library"],
    args = ["/ignore:4221"],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
)

cc_feature(
    name = "symbol_check_feature",
    args = [":symbol_check_flags"],
    feature_name = "symbol_check",
)

cc_args_for_compiler(
    name = "symbol_check_flags",
    actions = ["//cc/toolchains/actions:cpp_link_static_library"],
    args = ["/WX:4006"],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
)

cc_feature(
    name = "treat_warnings_as_errors_feature",
    args = [":treat_warnings_as_errors_flags"],
    feature_name = "treat_warnings_as_errors",
)

cc_args_for_compiler(
    name = "treat_warnings_as_errors_flags",
    actions = [
        "//cc/toolchains/actions:c_compile",
        "//cc/toolchains/actions:cpp_compile",
        "//cc/toolchains/actions:cpp_link_executable",
        "//cc/toolchains/actions:cpp_link_dynamic_library",
        "//cc/toolchains/actions:cpp_link_nodeps_dynamic_library",
    ],
    args = ["/WX"],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
)

cc_feature(
    name = "opt_feature",
    args = [
        ":opt_compile_flags",
    ],
    implies = [
        ":frame_pointer_feature",
        ":smaller_binary_feature",
        ":disable_assertions_feature",
    ],
    overrides = "//cc/toolchains/features:opt",
)

cc_args_for_compiler(
    name = "opt_compile_flags",
    actions = [
        "//cc/toolchains/actions:c_compile",
        "//cc/toolchains/actions:cpp_compile",
    ],
    args = [
        "/O2",
    ],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
)

cc_feature_constraint(
    name = "opt_enabled",
    all_of = ["//cc/toolchains/features:opt"],
)

cc_feature(
    name = "frame_pointer_feature",
    args = [":frame_pointer_flags"],
    feature_name = "frame_pointer",
)

cc_args_for_compiler(
    name = "frame_pointer_flags",
    actions = [
        "//cc/toolchains/actions:c_compile",
        "//cc/toolchains/actions:cpp_compile",
    ],
    args = ["/Oy-"],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    requires_any_of = [":opt_enabled"],
)

cc_feature(
    name = "smaller_binary_feature",
    args = [
        ":smaller_binary_compile_flags",
        ":smaller_binary_link_flags",
    ],
    feature_name = "smaller_binary",
)

cc_args_for_compiler(
    name = "smaller_binary_compile_flags",
    actions = [
        "//cc/toolchains/actions:c_compile",
        "//cc/toolchains/actions:cpp_compile",
    ],
    args = [
        "/Gy",
        "/Gw",
    ],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    requires_any_of = [":opt_enabled"],
)

cc_args_for_compiler(
    name = "smaller_binary_link_flags",
    actions = [
        "//cc/toolchains/actions:cpp_link_executable",
        "//cc/toolchains/actions:cpp_link_dynamic_library",
        "//cc/toolchains/actions:cpp_link_nodeps_dynamic_library",
    ],
    args = [
        "/OPT:ICF",
        "/OPT:REF",
    ],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    requires_any_of = [":opt_enabled"],
)

cc_feature(
    name = "disable_assertions_feature",
    args = [":disable_assertions_flags"],
    feature_name = "disable_assertions",
)

cc_args_for_compiler(
    name = "disable_assertions_flags",
    actions = [
        "//cc/toolchains/actions:c_compile",
        "//cc/toolchains/actions:cpp_compile",
    ],
    args = ["/DNDEBUG"],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    requires_any_of = [":opt_enabled"],
)

cc_feature(
    name = "dbg_feature",
    args = [
        ":dbg_compile_flags",
        ":dbg_link_flags",
    ],
    overrides = "//cc/toolchains/features:dbg",
)

cc_nested_args(
    name = "dbg_link_flag_from_variable",
    args = ["{dbg_mode_debug_flag}"],
    format = {"dbg_mode_debug_flag": "//cc/toolchains/variables:dbg_mode_debug_flag"},
    requires_not_none = "//cc/toolchains/variables:dbg_mode_debug_flag",
)

cc_nested_args(
    name = "dbg_link_flag_default",
    args = ["/DEBUG"],
    requires_none = "//cc/toolchains/variables:dbg_mode_debug_flag",
)

cc_nested_args(
    name = "dbg_incremental_no",
    args = ["/INCREMENTAL:NO"],
)

cc_args_for_compiler(
    name = "dbg_compile_flags",
    actions = [
        "//cc/toolchains/actions:c_compile",
        "//cc/toolchains/actions:cpp_compile",
    ],
    args = [
        "/Od",
        "/Z7",
    ],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
)

cc_args_for_compiler(
    name = "dbg_link_flags",
    actions = [
        "//cc/toolchains/actions:cpp_link_executable",
        "//cc/toolchains/actions:cpp_link_dynamic_library",
        "//cc/toolchains/actions:cpp_link_nodeps_dynamic_library",
    ],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    nested = [
        ":dbg_link_flag_from_variable",
        ":dbg_link_flag_default",
        ":dbg_incremental_no",
    ],
)

cc_feature(
    name = "fastbuild_feature",
    args = [
        ":fastbuild_compile_flags",
        ":fastbuild_link_flags",
    ],
    overrides = "//cc/toolchains/features:fastbuild",
)

cc_nested_args(
    name = "fastbuild_link_flag_from_variable",
    args = ["{fastbuild_mode_debug_flag}"],
    format = {"fastbuild_mode_debug_flag": "//cc/toolchains/variables:fastbuild_mode_debug_flag"},
    requires_not_none = "//cc/toolchains/variables:fastbuild_mode_debug_flag",
)

cc_nested_args(
    name = "fastbuild_link_flag_default",
    args = ["/DEBUG"],
    requires_none = "//cc/toolchains/variables:fastbuild_mode_debug_flag",
)

cc_nested_args(
    name = "fastbuild_incremental_no",
    args = ["/INCREMENTAL:NO"],
)

cc_args_for_compiler(
    name = "fastbuild_compile_flags",
    actions = [
        "//cc/toolchains/actions:c_compile",
        "//cc/toolchains/actions:cpp_compile",
    ],
    args = [
        "/Od",
        "/Z7",
    ],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
)

cc_args_for_compiler(
    name = "fastbuild_link_flags",
    actions = [
        "//cc/toolchains/actions:cpp_link_executable",
        "//cc/toolchains/actions:cpp_link_dynamic_library",
        "//cc/toolchains/actions:cpp_link_nodeps_dynamic_library",
    ],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    nested = [
        ":fastbuild_link_flag_from_variable",
        ":fastbuild_link_flag_default",
        ":fastbuild_incremental_no",
    ],
)

cc_mutually_exclusive_category(
    name = "msvcrt_link_mode",
)

cc_feature(
    name = "dynamic_link_msvcrt_feature",
    args = [":dynamic_link_msvcrt_flags"],
    feature_name = "dynamic_link_msvcrt",
)

cc_feature(
    name = "static_link_msvcrt_feature",
    args = [":static_link_msvcrt_flags"],
    feature_name = "static_link_msvcrt",
)

cc_feature_constraint(
    name = "msvcrt_dbg",
    all_of = ["//cc/toolchains/features:dbg"],
)

cc_feature_constraint(
    name = "msvcrt_no_dbg",
    none_of = ["//cc/toolchains/features:dbg"],
)

cc_feature_constraint(
    name = "msvcrt_no_static_link",
    none_of = [":static_link_msvcrt_feature"],
)

cc_feature_constraint(
    name = "msvcrt_dbg_no_static_link",
    all_of = [":msvcrt_dbg"],
    none_of = [":static_link_msvcrt_feature"],
)

cc_feature_constraint(
    name = "msvcrt_no_dbg_no_static_link",
    all_of = [":msvcrt_no_dbg"],
    none_of = [":static_link_msvcrt_feature"],
)

cc_args_list(
    name = "dynamic_link_msvcrt_flags",
    args = [
        ":dynamic_link_msvcrt_compile_flags",
        ":dynamic_link_msvcrt_compile_flags_dbg",
        ":dynamic_link_msvcrt_link_flags",
        ":dynamic_link_msvcrt_link_flags_dbg",
    ],
)

cc_args_list(
    name = "static_link_msvcrt_flags",
    args = [
        ":static_link_msvcrt_compile_flags",
        ":static_link_msvcrt_compile_flags_dbg",
        ":static_link_msvcrt_link_flags",
        ":static_link_msvcrt_link_flags_dbg",
    ],
)

cc_args_for_compiler(
    name = "dynamic_link_msvcrt_compile_flags",
    actions = [
        "//cc/toolchains/actions:c_compile",
        "//cc/toolchains/actions:cpp_compile",
    ],
    args = ["/MD"],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    requires_any_of = [":msvcrt_no_dbg_no_static_link"],
)

cc_args_for_compiler(
    name = "dynamic_link_msvcrt_compile_flags_dbg",
    actions = [
        "//cc/toolchains/actions:c_compile",
        "//cc/toolchains/actions:cpp_compile",
    ],
    args = ["/MDd"],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    requires_any_of = [":msvcrt_dbg_no_static_link"],
)

cc_args_for_compiler(
    name = "dynamic_link_msvcrt_link_flags",
    actions = ["//cc/toolchains/actions:link_actions"],
    args = [
        "/DEFAULTLIB:msvcrt.lib",
    ],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    requires_any_of = [":msvcrt_no_dbg_no_static_link"],
)

cc_args_for_compiler(
    name = "dynamic_link_msvcrt_link_flags_dbg",
    actions = ["//cc/toolchains/actions:link_actions"],
    args = [
        "/DEFAULTLIB:msvcrtd.lib",
    ],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    requires_any_of = [":msvcrt_dbg_no_static_link"],
)

cc_args_for_compiler(
    name = "static_link_msvcrt_compile_flags",
    actions = [
        "//cc/toolchains/actions:c_compile",
        "//cc/toolchains/actions:cpp_compile",
    ],
    args = ["/MT"],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    requires_any_of = [":msvcrt_no_dbg"],
)

cc_args_for_compiler(
    name = "static_link_msvcrt_compile_flags_dbg",
    actions = [
        "//cc/toolchains/actions:c_compile",
        "//cc/toolchains/actions:cpp_compile",
    ],
    args = ["/MTd"],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    requires_any_of = [":msvcrt_dbg"],
)

cc_args_for_compiler(
    name = "static_link_msvcrt_link_flags",
    actions = ["//cc/toolchains/actions:link_actions"],
    args = [
        "/DEFAULTLIB:libcmt.lib",
    ],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    requires_any_of = [":msvcrt_no_dbg"],
)

cc_args_for_compiler(
    name = "static_link_msvcrt_link_flags_dbg",
    actions = ["//cc/toolchains/actions:link_actions"],
    args = [
        "/DEFAULTLIB:libcmtd.lib",
    ],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    requires_any_of = [":msvcrt_dbg"],
)

cc_feature(
    name = "windows_machine_flags_feature",
    args = [":windows_machine_flags"],
    feature_name = "windows_machine_flags",
    visibility = ["//visibility:public"],
)

cc_args(
    name = "windows_machine_flags",
    actions = [
        "//cc/toolchains/actions:ar_actions",
        "//cc/toolchains/actions:cpp_link_executable",
        "//cc/toolchains/actions:cpp_link_dynamic_library",
        "//cc/toolchains/actions:cpp_link_nodeps_dynamic_library",
    ],
    args = select({
        "//cc/toolchains/impl:windows_x86_64": ["/MACHINE:X64"],
        "//cc/toolchains/impl:windows_x86_32": ["/MACHINE:X86"],
        "//cc/toolchains/impl:windows_aarch64": ["/MACHINE:ARM64"],
        "//conditions:default": [],
    }),
)
