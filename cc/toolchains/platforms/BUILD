load("@bazel_skylib//lib:selects.bzl", "selects")

selects.config_setting_group(
    name = "apple",
    match_any = [
        "@platforms//os:ios",
        "@platforms//os:macos",
        "@platforms//os:tvos",
        "@platforms//os:visionos",
        "@platforms//os:watchos",
    ],
    visibility = ["//visibility:public"],
)
