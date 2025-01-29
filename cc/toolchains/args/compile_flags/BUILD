load("//cc/toolchains:args.bzl", "cc_args")
load("//cc/toolchains:feature.bzl", "cc_feature")
load("//cc/toolchains:feature_set.bzl", "cc_feature_set")
load("//cc/toolchains:nested_args.bzl", "cc_nested_args")

cc_feature_set(
    name = "feature",
    all_of = [
        ":legacy_compile_flags_feature",
        ":user_compile_flags_feature",
        ":unfiltered_compile_flags_feature",
    ],
    visibility = ["//visibility:public"],
)

cc_feature(
    name = "legacy_compile_flags_feature",
    args = [":legacy_compile_flags"],
    overrides = "//cc/toolchains/features/legacy:legacy_compile_flags",
)

cc_args(
    name = "legacy_compile_flags",
    actions = ["//cc/toolchains/actions:compile_actions"],
    nested = [":iterate_over_legacy_compile_flags"],
    requires_not_none = "//cc/toolchains/variables:legacy_compile_flags",
)

cc_nested_args(
    name = "iterate_over_legacy_compile_flags",
    args = ["{legacy_compile_flags}"],
    format = {"legacy_compile_flags": "//cc/toolchains/variables:legacy_compile_flags"},
    iterate_over = "//cc/toolchains/variables:legacy_compile_flags",
)

cc_feature(
    name = "user_compile_flags_feature",
    args = [":user_compile_flags"],
    overrides = "//cc/toolchains/features/legacy:user_compile_flags",
)

cc_args(
    name = "user_compile_flags",
    actions = ["//cc/toolchains/actions:compile_actions"],
    nested = [":iterate_over_user_compile_flags"],
    requires_not_none = "//cc/toolchains/variables:user_compile_flags",
)

cc_nested_args(
    name = "iterate_over_user_compile_flags",
    args = ["{user_compile_flags}"],
    format = {"user_compile_flags": "//cc/toolchains/variables:user_compile_flags"},
    iterate_over = "//cc/toolchains/variables:user_compile_flags",
)

cc_feature(
    name = "unfiltered_compile_flags_feature",
    args = [":unfiltered_compile_flags"],
    overrides = "//cc/toolchains/features/legacy:unfiltered_compile_flags",
)

cc_args(
    name = "unfiltered_compile_flags",
    actions = ["//cc/toolchains/actions:compile_actions"],
    nested = [":iterate_over_unfiltered_compile_flags"],
    requires_not_none = "//cc/toolchains/variables:unfiltered_compile_flags",
)

cc_nested_args(
    name = "iterate_over_unfiltered_compile_flags",
    args = ["{unfiltered_compile_flags}"],
    format = {"unfiltered_compile_flags": "//cc/toolchains/variables:unfiltered_compile_flags"},
    iterate_over = "//cc/toolchains/variables:unfiltered_compile_flags",
)
