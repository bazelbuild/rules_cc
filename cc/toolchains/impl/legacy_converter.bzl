# Copyright 2024 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Conversion helper functions to legacy cc_toolchain_config_info."""

load(
    "//cc:cc_toolchain_config_lib.bzl",
    legacy_action_config = "action_config",
    legacy_env_entry = "env_entry",
    legacy_env_set = "env_set",
    legacy_feature = "feature",
    legacy_feature_set = "feature_set",
    legacy_flag_set = "flag_set",
    legacy_tool = "tool",
    legacy_with_feature_set = "with_feature_set",
)
load(
    "//cc/toolchains:cc_toolchain_info.bzl",
    "ArgsListInfo",
    "FeatureInfo",
)

visibility([
    "//cc/toolchains/...",
    "//tests/rule_based_toolchain/...",
])

# Note that throughout this file, we sort anything for which the order is
# nondeterministic (eg. depset's .to_list(), dictionary iteration).
# This allows our tests to call equals() on the output,
# and *may* provide better caching properties.

def _convert_actions(actions):
    return sorted([action.name for action in actions.to_list()])

def convert_feature_constraint(constraint):
    return legacy_with_feature_set(
        features = sorted([ft.name for ft in constraint.all_of.to_list()]),
        not_features = sorted([ft.name for ft in constraint.none_of.to_list()]),
    )

def convert_args(args):
    """Converts an ArgsInfo to flag_sets and env_sets.

    Args:
        args: (ArgsInfo) The args to convert
    Returns:
        struct(flag_sets = List[flag_set], env_sets = List[env_sets])
    """
    actions = _convert_actions(args.actions)
    with_features = [
        convert_feature_constraint(fc)
        for fc in args.requires_any_of
    ]

    flag_sets = []
    if args.nested != None:
        flag_sets.append(legacy_flag_set(
            actions = actions,
            with_features = with_features,
            flag_groups = [args.nested.legacy_flag_group],
        ))

    env_sets = []
    if args.env:
        env_sets.append(legacy_env_set(
            actions = actions,
            with_features = with_features,
            env_entries = [
                legacy_env_entry(
                    key = key,
                    value = value,
                )
                for key, value in args.env.items()
            ],
        ))
    return struct(
        flag_sets = flag_sets,
        env_sets = env_sets,
    )

def _convert_args_sequence(args_sequence):
    flag_sets = []
    env_sets = []
    for args in args_sequence:
        legacy_args = convert_args(args)
        flag_sets.extend(legacy_args.flag_sets)
        env_sets.extend(legacy_args.env_sets)

    return struct(flag_sets = flag_sets, env_sets = env_sets)

def convert_feature(feature):
    if feature.external:
        return None

    args = _convert_args_sequence(feature.args.args)

    return legacy_feature(
        name = feature.name,
        enabled = feature.enabled,
        flag_sets = args.flag_sets,
        env_sets = args.env_sets,
        implies = sorted([ft.name for ft in feature.implies.to_list()]),
        requires = [
            legacy_feature_set(sorted([
                feature.name
                for feature in requirement.features.to_list()
            ]))
            for requirement in feature.requires_any_of
        ],
        provides = [
            mutex.name
            for mutex in feature.mutually_exclusive
        ],
    )

def convert_tool(tool):
    return legacy_tool(
        tool = tool.exe,
        execution_requirements = list(tool.execution_requirements),
        with_features = [
            convert_feature_constraint(fc)
            for fc in tool.requires_any_of
        ],
    )

def _convert_action_type_config(atc):
    implies = sorted([ft.name for ft in atc.implies.to_list()])
    if atc.args:
        implies.append("implied_by_%s" % atc.action_type.name)

    return legacy_action_config(
        action_name = atc.action_type.name,
        enabled = True,
        tools = [convert_tool(tool) for tool in atc.tools],
        implies = implies,
    )

def convert_toolchain(toolchain):
    """Converts a rule-based toolchain into the legacy providers.

    Args:
        toolchain: CcToolchainConfigInfo: The toolchain config to convert.
    Returns:
        A struct containing parameters suitable to pass to
          cc_common.create_cc_toolchain_config_info.
    """
    features = [convert_feature(feature) for feature in toolchain.features]
    features.append(convert_feature(FeatureInfo(
        # We reserve names starting with implied_by. This ensures we don't
        # conflict with the name of a feature the user creates.
        name = "implied_by_always_enabled",
        enabled = True,
        args = ArgsListInfo(args = toolchain.args),
        implies = depset([]),
        requires_any_of = [],
        mutually_exclusive = [],
        external = False,
    )))
    action_configs = []
    for atc in toolchain.action_type_configs.values():
        # Action configs don't take in an env like they do a flag set.
        # In order to support them, we create a feature with the env that the action
        # config will enable, and imply it in the action config.
        if atc.args:
            features.append(convert_feature(FeatureInfo(
                name = "implied_by_%s" % atc.action_type.name,
                enabled = False,
                args = ArgsListInfo(args = atc.args),
                implies = depset([]),
                requires_any_of = [],
                mutually_exclusive = [],
                external = False,
            )))
        action_configs.append(_convert_action_type_config(atc))

    return struct(
        features = sorted([ft for ft in features if ft != None], key = lambda ft: ft.name),
        action_configs = sorted(action_configs, key = lambda ac: ac.action_name),
    )
