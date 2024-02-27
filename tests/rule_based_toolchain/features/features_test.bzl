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
"""Tests for actions for the rule based toolchain."""

load(
    "//cc/toolchains:cc_toolchain_info.bzl",
    "ArgsInfo",
    "FeatureInfo",
    "MutuallyExclusiveCategoryInfo",
)

visibility("private")

_C_COMPILE_FILE = "tests/rule_based_toolchain/testdata/file1"

def _simple_feature_test(env, targets):
    simple = env.expect.that_target(targets.simple).provider(FeatureInfo)
    simple.name().equals("feature_name")
    simple.args().args().contains_exactly([targets.c_compile.label])
    simple.enabled().equals(False)
    simple.overrides().is_none()
    simple.overridable().equals(False)

    simple.args().files().contains_exactly([_C_COMPILE_FILE])
    c_compile_action = simple.args().by_action().get(
        targets.c_compile[ArgsInfo].actions.to_list()[0],
    )
    c_compile_action.files().contains_exactly([_C_COMPILE_FILE])
    c_compile_action.args().contains_exactly([targets.c_compile[ArgsInfo]])

def _feature_collects_requirements_test(env, targets):
    env.expect.that_target(targets.requires).provider(
        FeatureInfo,
    ).requires_any_of().contains_exactly([
        targets.simple.label,
    ])

def _feature_collects_implies_test(env, targets):
    env.expect.that_target(targets.implies).provider(
        FeatureInfo,
    ).implies().contains_exactly([
        targets.simple.label,
    ])

def _feature_collects_mutual_exclusion_test(env, targets):
    env.expect.that_target(targets.simple).provider(
        MutuallyExclusiveCategoryInfo,
    ).name().equals("feature_name")
    env.expect.that_target(targets.mutual_exclusion_feature).provider(
        FeatureInfo,
    ).mutually_exclusive().contains_exactly([
        targets.simple.label,
    ])

TARGETS = [
    ":c_compile",
    ":simple",
    ":requires",
    ":implies",
    ":mutual_exclusion_feature",
]

# @unsorted-dict-items
TESTS = {
    "simple_feature_test": _simple_feature_test,
    "feature_collects_requirements_test": _feature_collects_requirements_test,
    "feature_collects_implies_test": _feature_collects_implies_test,
    "feature_collects_mutual_exclusion_test": _feature_collects_mutual_exclusion_test,
}
