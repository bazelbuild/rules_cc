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

def convert_feature(feature, enabled = False):
    if feature.external:
        return None

    args = _convert_args_sequence(feature.args.args)

    return legacy_feature(
        name = feature.name,
        enabled = enabled or feature.enabled,
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
        with_features = [],
    )

def convert_capability(capability):
    return legacy_feature(
        name = capability.name,
        enabled = False,
    )

def _convert_tool_map(tool_map):
    action_configs = []
    caps = {}
    for action_type, tool in tool_map.configs.items():
        action_configs.append(legacy_action_config(
            action_name = action_type.name,
            enabled = True,
            tools = [convert_tool(tool)],
            implies = [cap.feature.name for cap in tool.capabilities],
        ))
        for cap in tool.capabilities:
            caps[cap] = None

    cap_features = [
        legacy_feature(name = cap.feature.name, enabled = False)
        for cap in caps
    ]
    return action_configs, cap_features

def convert_toolchain(toolchain):
    """Converts a rule-based toolchain into the legacy providers.

    Args:
        toolchain: (ToolchainConfigInfo) The toolchain config to convert.
    Returns:
        A struct containing parameters suitable to pass to
          cc_common.create_cc_toolchain_config_info.
    """
    features = [
        convert_feature(feature, enabled = feature in toolchain.enabled_features)
        for feature in toolchain.features
    ]
    action_configs, cap_features = _convert_tool_map(toolchain.tool_map)
    features.extend(cap_features)
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
        allowlist_include_directories = depset(),
    )))

    cxx_builtin_include_directories = [
        d.path
        for d in toolchain.allowlist_include_directories.to_list()
    ]

    return struct(
        features = [ft for ft in features if ft != None],
        action_configs = sorted(action_configs, key = lambda ac: ac.action_name),
        cxx_builtin_include_directories = cxx_builtin_include_directories,
    )
