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
"""Helper functions to create and validate a ToolchainConfigInfo."""

load("//cc/toolchains:cc_toolchain_info.bzl", "ToolchainConfigInfo")
load(":args_utils.bzl", "get_action_type")
load(":collect.bzl", "collect_action_type_config_sets", "collect_args_lists", "collect_features")

visibility([
    "//cc/toolchains/...",
    "//tests/rule_based_toolchain/...",
])

_FEATURE_NAME_ERR = """The feature name {name} was defined by both {lhs} and {rhs}.

Possible causes:
* If you're overriding a feature in //cc/toolchains/features/..., then try adding the "overrides" parameter instead of specifying a feature name.
* If you intentionally have multiple features with the same name (eg. one for ARM and one for x86), then maybe you need add select() calls so that they're not defined at the same time.
* Otherwise, this is probably a real problem, and you need to give them different names.
"""

_INVALID_CONSTRAINT_ERR = """It is impossible to enable {provider}.

None of the entries in requires_any_of could be matched. This is required features are not implicitly added to the toolchain. It's likely that the feature that you require needs to be added to the toolchain explicitly.
"""

_UNKNOWN_FEATURE_ERR = """{self} implies the feature {ft}, which was unable to be found.

Implied features are not implicitly added to your toolchain. You likely need to add features = ["{ft}"] to your cc_toolchain rule.
"""

# Equality comparisons with bazel do not evaluate depsets.
# s = struct()
# d = depset([s])
# depset([s]) != depset([s])
# d == d
# This means that complex structs such as FeatureInfo will only compare as equal
# iff they are the *same* object or if there are no depsets inside them.
# Unfortunately, it seems that the FeatureInfo is copied during the
# cc_action_type_config rule. Ideally we'd like to fix that, but I don't really
# know what power we even have over such a thing.
def _feature_key(feature):
    # This should be sufficiently unique.
    return (feature.label, feature.name)

def _get_known_features(features, fail):
    feature_names = {}
    for ft in features:
        if ft.name in feature_names:
            other = feature_names[ft.name]
            if other.overrides != ft and ft.overrides != other:
                fail(_FEATURE_NAME_ERR.format(
                    name = ft.name,
                    lhs = ft.label,
                    rhs = other.label,
                ))
        feature_names[ft.name] = ft

    return {_feature_key(feature): None for feature in features}

def _can_theoretically_be_enabled(requirement, known_features):
    return all([
        _feature_key(ft) in known_features
        for ft in requirement
    ])

def _validate_requires_any_of(fn, self, known_features, fail):
    valid = any([
        _can_theoretically_be_enabled(fn(requirement), known_features)
        for requirement in self.requires_any_of
    ])

    # No constraints is always valid.
    if self.requires_any_of and not valid:
        fail(_INVALID_CONSTRAINT_ERR.format(provider = self.label))

def _validate_requires_any_of_constraint(self, known_features, fail):
    return _validate_requires_any_of(
        lambda constraint: constraint.all_of.to_list(),
        self,
        known_features,
        fail,
    )

def _validate_requires_any_of_feature_set(self, known_features, fail):
    return _validate_requires_any_of(
        lambda feature_set: feature_set.features.to_list(),
        self,
        known_features,
        fail,
    )

def _validate_implies(self, known_features, fail = fail):
    for ft in self.implies.to_list():
        if _feature_key(ft) not in known_features:
            fail(_UNKNOWN_FEATURE_ERR.format(self = self.label, ft = ft.label))

def _validate_args(self, known_features, fail):
    _validate_requires_any_of_constraint(self, known_features, fail = fail)

def _validate_tool(self, known_features, fail):
    _validate_requires_any_of_constraint(self, known_features, fail = fail)

def _validate_action_config(self, known_features, fail):
    _validate_implies(self, known_features, fail = fail)
    for tool in self.tools:
        _validate_tool(tool, known_features, fail = fail)
    for args in self.args:
        _validate_args(args, known_features, fail = fail)

def _validate_feature(self, known_features, fail):
    _validate_requires_any_of_feature_set(self, known_features, fail = fail)
    for arg in self.args.args:
        _validate_args(arg, known_features, fail = fail)
    _validate_implies(self, known_features, fail = fail)

def _validate_toolchain(self, fail = fail):
    known_features = _get_known_features(self.features, fail = fail)

    for feature in self.features:
        _validate_feature(feature, known_features, fail = fail)
    for atc in self.action_type_configs.values():
        _validate_action_config(atc, known_features, fail = fail)
    for args in self.args:
        _validate_args(args, known_features, fail = fail)

def _collect_files_for_action_type(atc, features, args):
    transitive_files = [atc.files.files, get_action_type(args, atc.action_type).files]
    for ft in features:
        transitive_files.append(get_action_type(ft.args, atc.action_type).files)

    return depset(transitive = transitive_files)

def toolchain_config_info(label, features = [], args = [], action_type_configs = [], fail = fail):
    """Generates and validates a ToolchainConfigInfo from lists of labels.

    Args:
        label: (Label) The label to apply to the ToolchainConfigInfo
        features: (List[Target]) A list of targets providing FeatureSetInfo
        args: (List[Target]) A list of targets providing ArgsListInfo
        action_type_configs: (List[Target]) A list of targets providing
          ActionTypeConfigSetInfo
        fail: A fail function. Use only during tests.
    Returns:
        A validated ToolchainConfigInfo
    """
    features = collect_features(features).to_list()
    args = collect_args_lists(args, label = label)
    action_type_configs = collect_action_type_config_sets(
        action_type_configs,
        label = label,
        fail = fail,
    ).configs
    files = {
        atc.action_type: _collect_files_for_action_type(atc, features, args)
        for atc in action_type_configs.values()
    }

    toolchain_config = ToolchainConfigInfo(
        label = label,
        features = features,
        action_type_configs = action_type_configs,
        args = args.args,
        files = files,
    )
    _validate_toolchain(toolchain_config, fail = fail)
    return toolchain_config
