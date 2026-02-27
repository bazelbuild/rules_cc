load("//cc/toolchains:feature.bzl", "cc_feature")
load("//cc/toolchains:feature_set.bzl", "cc_feature_set")
load("//cc/toolchains/impl:args_for_compiler.bzl", "cc_args_for_compiler")

WINDOWS_INCLUDE_PATH_ACTIONS = [
    "//cc/toolchains/actions:assemble",
    "//cc/toolchains/actions:preprocess_assemble",
    "//cc/toolchains/actions:c_compile",
    "//cc/toolchains/actions:linkstamp_compile",
    "//cc/toolchains/actions:cpp_compile",
    "//cc/toolchains/actions:cpp_header_parsing",
    "//cc/toolchains/actions:cpp_module_compile",
]

cc_feature_set(
    name = "feature",
    all_of = [
        ":includes_feature",
        ":include_paths_feature",
    ],
    visibility = ["//visibility:public"],
)

cc_feature(
    name = "includes_feature",
    args = [
        ":includes_flags",
    ],
    overrides = "//cc/toolchains/features/legacy:includes",
)

cc_args_for_compiler(
    name = "includes_flags",
    actions = ["//cc/toolchains/actions:source_compile_actions"],
    args = [
        "-include",
        "{includes}",
    ],
    exclude_compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    format = {"includes": "//cc/toolchains/variables:includes"},
    iterate_over = "//cc/toolchains/variables:includes",
    requires_not_none = "//cc/toolchains/variables:includes",
)

cc_feature(
    name = "include_paths_feature",
    args = [
        ":quote_include_paths_flags",
        ":quote_include_paths_flags_windows",
        ":include_paths_flags",
        ":include_paths_flags_windows",
        ":system_include_paths_flags",
        ":system_include_paths_flags_windows",
        ":framework_include_paths_flags",
        ":framework_include_paths_flags_windows",
    ],
    overrides = "//cc/toolchains/features/legacy:include_paths",
)

cc_args_for_compiler(
    name = "quote_include_paths_flags",
    actions = ["//cc/toolchains/actions:source_compile_actions"],
    args = [
        "-iquote",
        "{quote_include_paths}",
    ],
    exclude_compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    format = {"quote_include_paths": "//cc/toolchains/variables:quote_include_paths"},
    iterate_over = "//cc/toolchains/variables:quote_include_paths",
)

cc_args_for_compiler(
    name = "quote_include_paths_flags_windows",
    actions = WINDOWS_INCLUDE_PATH_ACTIONS,
    args = ["/I{quote_include_paths}"],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    format = {"quote_include_paths": "//cc/toolchains/variables:quote_include_paths"},
    iterate_over = "//cc/toolchains/variables:quote_include_paths",
)

cc_args_for_compiler(
    name = "include_paths_flags",
    actions = ["//cc/toolchains/actions:source_compile_actions"],
    args = [
        "-I{include_paths}",
    ],
    exclude_compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    format = {"include_paths": "//cc/toolchains/variables:include_paths"},
    iterate_over = "//cc/toolchains/variables:include_paths",
)

cc_args_for_compiler(
    name = "include_paths_flags_windows",
    actions = WINDOWS_INCLUDE_PATH_ACTIONS,
    args = ["/I{include_paths}"],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    format = {"include_paths": "//cc/toolchains/variables:include_paths"},
    iterate_over = "//cc/toolchains/variables:include_paths",
)

cc_args_for_compiler(
    name = "system_include_paths_flags",
    actions = ["//cc/toolchains/actions:source_compile_actions"],
    args = [
        "-isystem",
        "{system_include_paths}",
    ],
    exclude_compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    format = {"system_include_paths": "//cc/toolchains/variables:system_include_paths"},
    iterate_over = "//cc/toolchains/variables:system_include_paths",
)

cc_args_for_compiler(
    name = "system_include_paths_flags_windows",
    actions = WINDOWS_INCLUDE_PATH_ACTIONS,
    args = ["/I{system_include_paths}"],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    format = {"system_include_paths": "//cc/toolchains/variables:system_include_paths"},
    iterate_over = "//cc/toolchains/variables:system_include_paths",
)

cc_args_for_compiler(
    name = "framework_include_paths_flags",
    actions = ["//cc/toolchains/actions:source_compile_actions"],
    args = [
        "-F{framework_include_paths}",
    ],
    exclude_compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    format = {"framework_include_paths": "//cc/toolchains/variables:framework_include_paths"},
    iterate_over = "//cc/toolchains/variables:framework_include_paths",
)

cc_args_for_compiler(
    name = "framework_include_paths_flags_windows",
    actions = WINDOWS_INCLUDE_PATH_ACTIONS,
    args = [],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
)
