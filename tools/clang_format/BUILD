load("//tools/clang_format:clang_format.bzl", "clang_format", "clang_format_toolchain", "current_clang_format_toolchain")
load("//tools/clang_format/private:clang_format_utils.bzl", "string_list_flag")

package(default_visibility = ["//visibility:public"])

exports_files([
    "clang-format.yaml",
    "clang_format.bzl",
])

toolchain_type(name = "toolchain_type")

current_clang_format_toolchain(
    name = "current_clang_format_toolchain",
    tags = ["manual"],
)

label_flag(
    name = "clang_format_config",
    build_setting_default = "//tools/clang_format:clang-format.yaml",
    visibility = ["//visibility:public"],
)

string_list_flag(
    name = "clang_format_source_attrs",
    build_setting_default = [
        "srcs",
        "hdrs",
        "textual_hdrs",
    ],
)

string_list_flag(
    name = "clang_format_extensions",
    build_setting_default = [
        "asm",
        "bc",
        "c",
        "c++",
        "cc",
        "cl",
        "cpp",
        "cu",
        "cxx",
        "h",
        "h++",
        "hh",
        "hpp",
        "hxx",
        "i",
        "ii",
        "inc",
        "inc",
        "inl",
        "ipb",
        "ipp",
        "m",
        "mm",
        "opb",
        "pch",
        "s",
        "tcc",
        "tlh",
        "tli",
    ],
)

clang_format(
    name = "clang_format",
    tags = ["manual"],
)

filegroup(
    name = "bzl_srcs",
    srcs = glob([
        "**/*.bzl",
    ]) + [
        "//tools/clang_format/private:bzl_srcs",
    ],
)

clang_format_toolchain(
    name = "clang_format_toolchain_impl",
    clang_format_path = "clang-format",
)

toolchain(
    name = "clang_format_toolchain",
    toolchain = "clang_format_toolchain_impl",
    toolchain_type = "@rules_cc//tools/clang_format:toolchain_type",
)
