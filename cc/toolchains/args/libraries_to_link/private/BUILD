load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "srcs",
    srcs = [
        "BUILD",
        "library_link_args.bzl",
    ],
    visibility = ["//cc/toolchains/args/libraries_to_link:__pkg__"],
)

bzl_library(
    name = "library_link_args",
    srcs = ["library_link_args.bzl"],
    deps = ["//cc/toolchains:nested_args"],
)
