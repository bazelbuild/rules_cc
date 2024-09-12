load("//cc/toolchains:args.bzl", "cc_args")

package(default_visibility = ["//visibility:private"])

cc_args(
    name = "shared_flag",
    actions = ["//cc/toolchains/actions:dynamic_library_link_actions"],
    args = ["-shared"],
    visibility = ["//visibility:public"],
)
