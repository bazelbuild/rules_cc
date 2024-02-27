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
"""Implementation of the cc_external_feature rule."""

load(
    "//cc/toolchains:cc_toolchain_info.bzl",
    "ArgsListInfo",
    "FeatureConstraintInfo",
    "FeatureInfo",
    "FeatureSetInfo",
)

visibility([
    "//cc/toolchains/...",
    "//tests/rule_based_toolchain/...",
])

def _cc_external_feature_impl(ctx):
    feature = FeatureInfo(
        label = ctx.label,
        name = ctx.attr.feature_name,
        enabled = False,
        args = ArgsListInfo(
            label = ctx.label,
            args = (),
            files = depset([]),
            by_action = (),
        ),
        implies = depset([]),
        requires_any_of = (),
        mutually_exclusive = (),
        external = True,
        overridable = ctx.attr.overridable,
        overrides = None,
    )
    providers = [
        feature,
        FeatureSetInfo(label = ctx.label, features = depset([feature])),
        FeatureConstraintInfo(
            label = ctx.label,
            all_of = depset([feature]),
            none_of = depset([]),
        ),
    ]
    return providers

cc_external_feature = rule(
    implementation = _cc_external_feature_impl,
    attrs = {
        "feature_name": attr.string(
            mandatory = True,
            doc = "The name of the feature",
        ),
        "overridable": attr.bool(
            doc = "Whether the feature can be overridden",
            mandatory = True,
        ),
    },
    provides = [FeatureInfo, FeatureSetInfo, FeatureConstraintInfo],
    doc = "A declaration that a feature with this name is defined elsewhere.",
)
