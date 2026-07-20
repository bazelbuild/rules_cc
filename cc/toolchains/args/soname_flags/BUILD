load("//cc/toolchains:args.bzl", "cc_args")
load("//cc/toolchains:feature.bzl", "cc_feature")

cc_feature(
    name = "feature",
    args = [":set_soname_args"],
    feature_name = "set_soname",  # Feature name is important and read by rules_cc
    visibility = ["//visibility:public"],
)

cc_args(
    name = "set_soname_args",
    actions = ["//cc/toolchains/actions:dynamic_library_link_actions"],
    args = select({
        "//cc/settings:apple_constraint": ["-Wl,-install_name,@rpath/{runtime_solib_name}"],
        "@platforms//os:linux": ["-Wl,-soname,{runtime_solib_name}"],
        "//conditions:default": [],
    }),
    format = {"runtime_solib_name": "//cc/toolchains/variables:runtime_solib_name"},
    requires_not_none = "//cc/toolchains/variables:runtime_solib_name",
)
