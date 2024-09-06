load("//cc/toolchains:args.bzl", "cc_args")

package(default_visibility = ["//visibility:private"])

cc_args(
    name = "force_pic_flags",
    actions = [
        "//cc/toolchains/actions:cpp_link_executable",
        "//cc/toolchains/actions:lto_index_for_executable",
    ],
    args = select({
        "@platforms//os:macos": ["-Wl,-pie"],
        "//conditions:default": ["-pie"],
    }),
    requires_not_none = "//cc/toolchains/variables:force_pic",
    visibility = ["//visibility:public"],
)
