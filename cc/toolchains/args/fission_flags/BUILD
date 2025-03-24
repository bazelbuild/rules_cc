load("//cc/toolchains:args.bzl", "cc_args")
load("//cc/toolchains:feature.bzl", "cc_feature")

cc_feature(
    name = "feature",
    args = [":flags"],
    overrides = "//cc/toolchains/features/legacy:fission_support",
    visibility = ["//visibility:public"],
)

cc_args(
    name = "flags",
    actions = ["//cc/toolchains/actions:link_actions"],
    args = ["-Wl,--gdb-index"],
    requires_not_none = "//cc/toolchains/variables:is_using_fission",
)
