load("//cc/toolchains:args.bzl", "cc_args")

package(default_visibility = ["//visibility:private"])

cc_args(
    name = "force_pic_flags",
    actions = ["//cc/toolchains/actions:link_executable_actions"],
    args = select({
        "@platforms//os:macos": ["-Wl,-pie"],
        "//conditions:default": ["-pie"],
    }),
    requires_not_none = "//cc/toolchains/variables:force_pic",
    visibility = ["//visibility:public"],
)
