load("@rules_cc//cc:defs.bzl", "cc_library")
load("@rules_cc//examples:experimental_cc_shared_library.bzl", "exported_by")

cc_library(
    name = "bar",
    srcs = ["bar.cc"],
    hdrs = ["bar.h"],
    tags = [exported_by(["@rules_cc//examples/test_cc_shared_library:bar_so"])],
    visibility = ["//visibility:public"],
)
