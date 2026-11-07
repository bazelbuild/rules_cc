load("//cc:cc_library.bzl", "cc_library")

licenses(["notice"])

cc_library(
    name = "runfiles",
    srcs = ["runfiles.cc"],
    hdrs = ["runfiles.h"],
    include_prefix = "rules_cc/cc/runfiles",
    strip_include_prefix = ".",
    # The library has no global state, so it is safe to link it into several
    # cc_shared_libraries that end up in the same process.
    tags = ["LINKABLE_MORE_THAN_ONCE"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "srcs",
    srcs = glob([
        "*.cc",
        "*.h",
    ]) + [
        "BUILD",
    ],
    visibility = ["//visibility:public"],
)
