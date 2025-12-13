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
"""Implementation of the cc_target_capability rule."""

load(
    ":cc_toolchain_info.bzl",
    "ArgsListInfo",
    "FeatureConstraintInfo",
    "FeatureInfo",
    "FeatureSetInfo",
    "TargetCapabilityInfo",
)

def _cc_target_capability_impl(ctx):
    ft = FeatureInfo(
        name = ctx.attr.feature_name or ctx.label.name,
        label = ctx.label,
        enabled = False,
        args = ArgsListInfo(
            label = ctx.label,
            args = (),
            files = depset(),
            by_action = (),
            allowlist_include_directories = depset(),
        ),
        implies = depset(),
        requires_any_of = (),
        mutually_exclusive = (),
        external = False,
        overridable = True,
        overrides = None,
        allowlist_include_directories = depset(),
    )

    # Intentionally does not provide FeatureImplyabilityInfo to prevent
    # features from implying these kinds of rules.
    return [
        ft,
        FeatureSetInfo(label = ctx.label, features = depset([ft])),
        TargetCapabilityInfo(label = ctx.label, feature = ft),
        FeatureConstraintInfo(label = ctx.label, all_of = depset([ft])),
    ]

cc_target_capability = rule(
    implementation = _cc_target_capability_impl,
    provides = [TargetCapabilityInfo, FeatureSetInfo, FeatureConstraintInfo],
    doc = """A target capability is an optional feature that a target platform supports.

For example, not all target platforms have dynamic loaders (e.g. microcontroller
firmware), so a toolchain may conditionally enable the capabilty to communicate
the capability to C/C++ rule implementations.

```
load("//cc/toolchains:toolchain.bzl", "cc_toolchain")

cc_toolchain(
    name = "universal_cc_toolchain",
    # Assume no operating system means no dynamic loader support.
    enabled_features = select({
        "@platforms//os:none": [],
        "//conditions:default": [
            "//cc/toolchains/capabilities:supports_dynamic_linker",
        ],
    }),
    # ...
)
```

`cc_target_capability` rules cannot be listed in a
[`cc_feature.implies`](#cc_feature-implies) list.

Note: User-defined capabilities should prefer traditional
[user-defined build settings](https://bazel.build/extending/config#user-defined-build-settings).
This construct exists to communicate these features to preexisting C/C++ rule
implementations that expect these options to be exposed as
[features](https://bazel.build/docs/cc-toolchain-config-reference#features).
""",
    attrs = {
        "feature_name": attr.string(doc = "The name of the feature to generate for this capability"),
    },
)
