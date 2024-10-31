load("@rules_cc//cc:cc_library.bzl", "cc_library")

licenses(["notice"])

cc_library(
    name = "runfiles",
    srcs = ["runfiles.cc"],
    hdrs = ["runfiles.h"],
    # Ensure that this header can be included from the same directory as the
    # legacy @bazel_tools//tools/cpp/runfiles library.
    include_prefix = "tools/cpp/runfiles",
    strip_include_prefix = ".",
    visibility = ["//visibility:public"],
)
