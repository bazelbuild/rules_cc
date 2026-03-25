load("//cc/toolchains:args.bzl", "cc_args")
load("//cc/toolchains:feature.bzl", "cc_feature")

cc_feature(
    name = "feature",
    args = [":sanitize_pwd"],
    # The feature name matters: finalize_link_action.bzl checks for
    # "sanitize_pwd" by name to skip legacy PWD env logic.
    feature_name = "sanitize_pwd",
    visibility = ["//visibility:public"],
)

cc_args(
    name = "sanitize_pwd",
    actions = [
        "//cc/toolchains/actions:ar_actions",
        "//cc/toolchains/actions:link_actions",
        "//cc/toolchains/actions:objc_fully_link",
    ],
    env = select({
        "@platforms//os:macos": {},
        "//conditions:default": {"PWD": "/proc/self/cwd"},
    }),
)
