load("@bazel_skylib//lib:selects.bzl", "selects")

selects.config_setting_group(
    name = "default_apple_constraint",
    match_any = [
        "@platforms//os:ios",
        "@platforms//os:macos",
        "@platforms//os:tvos",
        "@platforms//os:visionos",
        "@platforms//os:watchos",
    ],
    visibility = ["//visibility:private"],
)

label_flag(
    name = "apple_constraint",
    build_setting_default = ":default_apple_constraint",
    visibility = ["//visibility:public"],
)
