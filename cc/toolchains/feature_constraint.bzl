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
"""Implementation of the cc_feature_constraint rule."""

load(
    "//cc/toolchains/impl:collect.bzl",
    "collect_features",
    "collect_provider",
)
load(
    ":cc_toolchain_info.bzl",
    "FeatureConstraintInfo",
    "FeatureSetInfo",
)

def _cc_feature_constraint_impl(ctx):
    if ctx.attr.features:
        fail("Features is a reserved attribute in bazel. Use the attributes `all_of` and `none_of` for feature constraints")
    all_of = collect_provider(ctx.attr.all_of, FeatureConstraintInfo)
    none_of = [collect_features(ctx.attr.none_of)]
    none_of.extend([fc.none_of for fc in all_of])
    return [FeatureConstraintInfo(
        label = ctx.label,
        all_of = depset(transitive = [fc.all_of for fc in all_of]),
        none_of = depset(transitive = none_of),
    )]

cc_feature_constraint = rule(
    implementation = _cc_feature_constraint_impl,
    attrs = {
        "all_of": attr.label_list(
            providers = [FeatureConstraintInfo],
        ),
        "none_of": attr.label_list(
            providers = [FeatureSetInfo],
        ),
    },
    provides = [FeatureConstraintInfo],
    doc = """Defines a constraint on features.

Can be used with require_any_of to specify that something is only enabled when
a constraint is met.""",
)
