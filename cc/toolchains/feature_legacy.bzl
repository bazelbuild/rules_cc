load("//cc:cc_toolchain_config_lib.bzl", "EnvSetInfo", "FeatureInfo", "FeatureSetInfo", "FlagGroupInfo", "FlagSetInfo", "WithFeatureSetInfo")

def _cc_flag_group_legacy_impl(ctx):
    return [
        FlagGroupInfo(
            flags = ctx.attr.flags,
            flag_groups = [flag_group[FlagGroupInfo] for flag_group in ctx.attr.flag_groups],
            # string does not accept None as default, because of that we need to convert empty string to None
            iterate_over = ctx.attr.iterate_over if ctx.attr.iterate_over else None,
            expand_if_available = ctx.attr.expand_if_available if ctx.attr.expand_if_available else None,
            expand_if_not_available = ctx.attr.expand_if_not_available if ctx.attr.expand_if_not_available else None,
            expand_if_true = ctx.attr.expand_if_true if ctx.attr.expand_if_true else None,
            expand_if_false = ctx.attr.expand_if_false if ctx.attr.expand_if_false else None,
            expand_if_equal = ctx.attr.expand_if_equal if ctx.attr.expand_if_equal else None,
            type_name = "flag_group",
        ),
    ]

cc_flag_group_legacy = rule(
    implementation = _cc_flag_group_legacy_impl,
    attrs = {
        "flags": attr.string_list(
            default = [],
        ),
        "flag_groups": attr.label_list(
            providers = [FlagGroupInfo],
            default = [],
        ),
        "iterate_over": attr.string(),
        "expand_if_available": attr.string(),
        "expand_if_not_available": attr.string(),
        "expand_if_true": attr.string(),
        "expand_if_false": attr.string(),
        "expand_if_equal": attr.string(),
    },
)

def _cc_flag_set_legacy_impl(ctx):
    return [
        FlagSetInfo(
            actions = ctx.attr.actions,
            with_features = [feature[WithFeatureSetInfo] for feature in ctx.attr.with_features],
            flag_groups = [flag_group[FlagGroupInfo] for flag_group in ctx.attr.flag_groups],
            type_name = "flag_set",
        ),
    ]

cc_flag_set_legacy = rule(
    implementation = _cc_flag_set_legacy_impl,
    attrs = {
        "actions": attr.string_list(
            default = [],
        ),
        "with_features": attr.label_list(
            providers = [WithFeatureSetInfo],
            default = [],
        ),
        "flag_groups": attr.label_list(
            providers = [FlagGroupInfo],
            default = [],
        ),
    },
)

def _cc_feature_legacy_impl(ctx):
    return [
        FeatureInfo(
            name = ctx.label.name,
            enabled = ctx.attr.enabled,
            flag_sets = [flag_set[FlagSetInfo] for flag_set in ctx.attr.flag_sets],
            env_sets = [env_set[EnvSetInfo] for env_set in ctx.attr.env_sets],
            requires = [require[FeatureSetInfo] for require in ctx.attr.requires],
            implies = ctx.attr.implies,
            provides = ctx.attr.provides,
            type_name = "feature",
        ),
    ]

cc_feature_legacy = rule(
    implementation = _cc_feature_legacy_impl,
    attrs = {
        "enabled": attr.bool(default = False),
        "flag_sets": attr.label_list(
            providers = [FlagSetInfo],
            default = [],
        ),
        "env_sets": attr.label_list(
            providers = [EnvSetInfo],
            default = [],
        ),
        "requires": attr.label_list(
            providers = [FeatureSetInfo],
            default = [],
        ),
        "implies": attr.string_list(
            default = [],
        ),
        "provides": attr.string_list(
            default = [],
        ),
    },
)
