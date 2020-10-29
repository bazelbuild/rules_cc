load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

package(default_visibility = ["//visibility:public"])

licenses(["notice"])  # Apache 2.0

filegroup(
    name = "srcs",
    srcs = glob([
        "**/*.bzl",
        "**/BUILD",
    ]),
)

bzl_library(
    name = "cc_flags_supplier",
    srcs = ["cc_flags_supplier.bzl"],
    deps = [
        "@rules_cc//cc:action_names",
        "@rules_cc//cc:find_cc_toolchain",
        "@rules_cc//cc/private/rules_impl:cc_flags_supplier_lib",
    ],
)

bzl_library(
    name = "cc_flags_supplier_lib",
    srcs = ["cc_flags_supplier_lib.bzl"],
)

bzl_library(
    name = "compiler_flag",
    srcs = ["compiler_flag.bzl"],
    deps = ["@rules_cc//cc:find_cc_toolchain"],
)
