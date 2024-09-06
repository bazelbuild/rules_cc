load("@bazel_skylib//rules/directory:directory.bzl", "directory")
load("@bazel_skylib//rules/directory:subdirectory.bzl", "subdirectory")
load("@rules_cc//cc/toolchains/args:sysroot.bzl", "cc_sysroot")

package(default_visibility = ["//visibility:public"])

cc_sysroot(
    name = "sysroot",
    sysroot = ":root",
    data = [":root"],
    allowlist_include_directories = [
        ":usr-include-x86_64-linux-gnu",
        ":usr-include",
    ],
)

directory(
    name = "root",
    srcs = glob(["**/*"]),
)

subdirectory(
    name = "usr-include-x86_64-linux-gnu",
    path = "usr/include/x86_64-linux-gnu",
    parent = ":root",
)

subdirectory(
    name = "usr-include",
    path = "usr/include",
    parent = ":root",
)
