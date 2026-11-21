# Copyright 2026 The Bazel Authors. All rights reserved.
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

load("@rules_cc//cc/toolchains:cc_toolchain_info.bzl", _FeatureInfo = "FeatureInfo")
load("@rules_cc//cc/toolchains/impl:legacy_converter.bzl", _convert_feature = "convert_feature")

convert_feature = _convert_feature
FeatureInfo = _FeatureInfo

def convert_extra_features(*, enabled, known):
    """Returns legacy feature definitions for the injected feature targets.

    Args:
      enabled: Feature targets whose definitions should be enabled.
      known: Additional feature targets whose definitions should be available.

    Returns:
      The converted definitions. External feature targets refer to definitions
      supplied elsewhere, so they do not contribute a definition here.
    """
    features = []
    for target in depset(enabled + known).to_list():
        feature = _convert_feature(target[_FeatureInfo], enabled = target in enabled)
        if feature != None:
            features.append(feature)
    return features
