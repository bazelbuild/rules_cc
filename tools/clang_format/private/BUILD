load("@rules_cc//cc:defs.bzl", "cc_binary", "cc_library")
load(":clang_format_utils.bzl", "bool_setting", "build_setting_file", "workspace_header")

exports_files(
    [
        "clang_format_runner.cc",
    ],
    visibility = ["//visibility:public"],
)

workspace_header(
    name = "clang_format_workspace.h",
)

cc_library(
    name = "clang_format_utils",
    srcs = ["clang_format_utils.cc"],
    hdrs = [
        "clang_format_utils.h",
        "clang_format_workspace.h",
    ],
    defines = [
        "WORKSPACE_HEADER=\\\"{}{}\\\"".format(
            package_name() + "/" if package_name() else "",
            "clang_format_workspace.h",
        ),
    ],
    visibility = ["//visibility:public"],
)

cc_binary(
    name = "clang_format_process_wrapper",
    srcs = ["clang_format_process_wrapper.cc"],
    visibility = ["//visibility:public"],
    deps = [":clang_format_utils"],
)

build_setting_file(
    name = "clang_format_extensions_file",
    setting = "//tools/clang_format:clang_format_extensions",
    visibility = ["//visibility:public"],
)

bool_setting(
    name = "is_windows",
    value = select({
        "@platforms//os:windows": True,
        "//conditions:default": False,
    }),
    visibility = ["//visibility:public"],
)

filegroup(
    name = "bzl_srcs",
    srcs = glob([
        "**/*.bzl",
    ]),
    visibility = ["//:__subpackages__"],
)
