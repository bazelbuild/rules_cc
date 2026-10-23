# Copyright 2024 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Provides necessary tools to inject rules-based features to legacy toolchains"""

load("@rules_cc//cc/toolchains:cc_toolchain_info.bzl", _FeatureInfo = "FeatureInfo", _FeatureSetInfo = "FeatureSetInfo")
load("@rules_cc//cc/toolchains/impl:legacy_converter.bzl", _convert_feature = "convert_feature")

convert_feature = _convert_feature
FeatureInfo = _FeatureInfo
FeatureSetInfo = _FeatureSetInfo

# Accepted providers for attributes that inject rules-based features. Both
# `cc_feature` and `cc_feature_set` targets may be listed.
INJECTED_FEATURE_PROVIDERS = [[FeatureInfo], [FeatureSetInfo]]

def _collect_features(targets):
    features = {}
    for target in targets:
        if FeatureSetInfo in target:
            for feature in target[FeatureSetInfo].features.to_list():
                features[feature.label] = feature
        else:
            feature = target[FeatureInfo]
            features[feature.label] = feature
    return features

def convert_injected_features(enabled_targets, known_targets):
    """Converts injected `cc_feature` / `cc_feature_set` targets into legacy features.

    Args:
        enabled_targets: (List[Target]) Features to add in an initially enabled state.
        known_targets: (List[Target]) Features to add in an initially disabled state.

    Returns:
        (List[feature]) Legacy `feature` structs, enabled ones first, with duplicates
        removed. Features that are only declarations of externally defined features
        are skipped.
    """
    enabled = _collect_features(enabled_targets)
    known = _collect_features(known_targets)

    all_features = dict(enabled)
    for label, feature in known.items():
        all_features.setdefault(label, feature)

    converted = []
    for label, feature in all_features.items():
        legacy = convert_feature(feature, enabled = label in enabled)
        if legacy != None:
            converted.append(legacy)
    return converted
