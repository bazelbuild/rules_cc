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
"""Implementation of the cc_feature_set rule."""

load("//cc/toolchains/impl:collect.bzl", "collect_features")
load("//cc/toolchains/impl:features_attr.bzl", "require_features_attr")
load(
    ":cc_toolchain_info.bzl",
    "FeatureConstraintInfo",
    "FeatureSetInfo",
)

def _cc_feature_set_impl(ctx):
    features = collect_features(ctx.attr.features_)
    return [
        FeatureSetInfo(label = ctx.label, features = features),
        FeatureConstraintInfo(
            label = ctx.label,
            all_of = features,
            none_of = depset([]),
        ),
    ]

_cc_feature_set = rule(
    implementation = _cc_feature_set_impl,
    attrs = {
        "features_": attr.label_list(
            providers = [FeatureSetInfo],
            doc = "A set of features",
        ),
    },
    provides = [FeatureSetInfo],
    doc = """Defines a set of features.

Example:

    cc_feature_set(
        name = "thin_lto_requirements",
        all_of = [
            ":thin_lto",
            ":opt",
        ],
    )
""",
)
cc_feature_set = require_features_attr(_cc_feature_set)
