load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

package(default_visibility = ["//visibility:public"])

licenses(["notice"])  # Apache 2.0

filegroup(
    name = "bzl_srcs",
    srcs = glob([
        "**/*.bzl",
    ]),
)

filegroup(
    name = "srcs",
    srcs = glob([
        "**/*.bzl",
        "**/BUILD",
    ]),
)

bzl_library(
    name = "cc_flags_supplier_lib_bzl",
    srcs = ["cc_flags_supplier_lib.bzl"],
    visibility = ["//cc:__subpackages__"],
    deps = ["//cc/common"],
)

bzl_library(
    name = "core_rules",
    srcs = [
        "cc_binary.bzl",
        "cc_import.bzl",
        "cc_library.bzl",
        "cc_shared_library.bzl",
        "cc_static_library.bzl",
        "cc_test.bzl",
        "failing_cc_proto_library.bzl",
        "objc_import.bzl",
        "objc_library.bzl",
    ],
    visibility = ["//cc:__subpackages__"],
    deps = ["//cc/common"],
)

bzl_library(
    name = "objc_common",
    srcs = [
        "objc_common.bzl",
        "objc_compilation_context_info.bzl",
    ],
    visibility = ["//cc:__subpackages__"],
)

bzl_library(
    name = "native_bzl",
    srcs = ["native.bzl"],
    visibility = ["//cc:__subpackages__"],
)
