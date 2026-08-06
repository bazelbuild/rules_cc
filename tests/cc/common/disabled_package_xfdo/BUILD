load("@rules_testing//lib:util.bzl", "util")
load("//cc:cc_binary.bzl", "cc_binary")
load("//cc/toolchains:fdo_profile.bzl", "fdo_profile")

package(features = ["-thin_lto"])

util.helper_target(
    cc_binary,
    name = "bin",
    srcs = ["empty.cc"],
    visibility = ["//tests/cc/common:__pkg__"],
)

fdo_profile(
    name = "out.xfdo",
    profile = "profiles.xfdo",
    visibility = ["//tests/cc/common:__pkg__"],
)
