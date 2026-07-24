load("//cc:cc_library.bzl", "cc_library")

licenses(["notice"])

cc_library(
    name = "runfiles",
    srcs = ["runfiles.cc"],
    hdrs = ["runfiles.h"],
    implementation_deps = [":runfiles_c"],
    include_prefix = "rules_cc/cc/runfiles",
    strip_include_prefix = ".",
    visibility = ["//visibility:public"],
)

cc_library(
    name = "runfiles_c",
    srcs = ["runfiles_c.c"],
    hdrs = [
        "runfiles_c.h",
        "runfiles_c_internal.h",
    ],
    include_prefix = "rules_cc/cc/runfiles",
    strip_include_prefix = ".",
    visibility = ["//visibility:public"],
)

filegroup(
    name = "srcs",
    srcs = glob([
        "*.c",
        "*.cc",
        "*.h",
    ]) + [
        "BUILD",
    ],
    visibility = ["//visibility:public"],
)
