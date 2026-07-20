load("//cc/toolchains:args.bzl", "cc_args")
load("//cc/toolchains:feature.bzl", "cc_feature")
load("//cc/toolchains:feature_set.bzl", "cc_feature_set")

cc_feature_set(
    name = "feature",
    all_of = select({
        "//cc/settings:apple_constraint": [":set_install_name_feature"],
        "@platforms//os:linux": [":set_soname_feature"],
        "//conditions:default": [],
    }),
    visibility = ["//visibility:public"],
)

cc_feature(
    name = "set_install_name_feature",
    args = [":apple_set_install_name"],
    feature_name = "set_install_name",  # Doesn't override legacy feature, but shouldn't be disabled, mirrors default toolchain name
)

cc_args(
    name = "apple_set_install_name",
    actions = ["//cc/toolchains/actions:dynamic_library_link_actions"],
    args = ["-Wl,-install_name,@rpath/{runtime_solib_name}"],
    format = {"runtime_solib_name": "//cc/toolchains/variables:runtime_solib_name"},
    requires_not_none = "//cc/toolchains/variables:runtime_solib_name",
    target_compatible_with = ["//cc/settings:apple_constraint"],
)

cc_feature(
    name = "set_soname_feature",
    args = [":set_soname"],
    feature_name = "set_soname",  # Feature name is important and read by rules_cc
    visibility = ["//visibility:public"],
)

cc_args(
    name = "set_soname",
    actions = ["//cc/toolchains/actions:dynamic_library_link_actions"],
    args = ["-Wl,-soname,{runtime_solib_name}"],
    format = {"runtime_solib_name": "//cc/toolchains/variables:runtime_solib_name"},
    requires_not_none = "//cc/toolchains/variables:runtime_solib_name",
    target_compatible_with = ["@platforms//os:linux"],
    visibility = ["//visibility:public"],
)
