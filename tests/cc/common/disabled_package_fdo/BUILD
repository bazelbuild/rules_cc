load("@rules_testing//lib:util.bzl", "util")
load("//cc:cc_binary.bzl", "cc_binary")

package(features = ["-thin_lto"])

util.helper_target(
    cc_binary,
    name = "bin",
    srcs = ["empty.cc"],
    visibility = ["//tests/cc/common:__pkg__"],
)
