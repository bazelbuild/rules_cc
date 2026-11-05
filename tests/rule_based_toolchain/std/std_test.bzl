# Copyright 2026 The Bazel Authors. All rights reserved.
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
"""Tests for the C and C++ language standard features."""

load("//cc:cc_toolchain_config_lib.bzl", legacy_flag_group = "flag_group")
load(
    "//cc/toolchains:cc_toolchain_info.bzl",
    "FeatureConstraintInfo",
    "FeatureSetInfo",
    "MutuallyExclusiveCategoryInfo",
)
load(
    "//cc/toolchains/args/std:standards.bzl",
    "CPP_STANDARDS",
    "C_STANDARDS",
    "MSVC_CPP_STANDARDS",
    "MSVC_C_STANDARDS",
)
load(
    "//cc/toolchains/impl:legacy_converter.bzl",
    "convert_feature",
    "convert_feature_constraint",
)

visibility("private")

_C_ACTIONS = ["c-compile"]

_CPP_ACTIONS = [
    "c++-compile",
    "c++-header-parsing",
    "c++-module-codegen",
    "c++-module-compile",
    "c++20-module-codegen",
    "c++20-module-compile",
    "c++-module-deps-scanning",
    "clif-match",
    "linkstamp-compile",
    "objc++-compile",
]

def _gnu_flags(standards):
    return {std: ["-std=" + std] for std in standards}

def _msvc_flags(standards):
    return {std: [flag] for std, flag in standards.items()}

def _check_std_features(env, feature_set, category, expected_flags, actions):
    features = feature_set[FeatureSetInfo].features.to_list()
    env.expect.that_collection([ft.name for ft in features]).contains_exactly(expected_flags.keys())

    for ft in features:
        env.expect.that_collection([
            mutex.label
            for mutex in ft.mutually_exclusive
        ]).contains_exactly([category.label])

        legacy = convert_feature(ft)
        env.expect.that_str(legacy.name).equals(ft.name)
        env.expect.that_bool(legacy.enabled).equals(False)
        env.expect.that_collection(legacy.provides).contains_exactly([
            category[MutuallyExclusiveCategoryInfo].name,
        ])
        env.expect.that_collection(legacy.flag_sets).has_size(1)
        flag_set = legacy.flag_sets[0]
        env.expect.that_collection(flag_set.actions).contains_exactly(actions)
        env.expect.that_collection(flag_set.with_features).contains_exactly([])
        env.expect.that_collection(flag_set.flag_groups).contains_exactly([
            legacy_flag_group(flags = expected_flags[ft.name]),
        ])

def _check_unspecified_constraint(env, constraint, standards):
    info = constraint[FeatureConstraintInfo]
    env.expect.that_collection(info.all_of.to_list()).contains_exactly([])
    env.expect.that_collection([
        ft.name
        for ft in info.none_of.to_list()
    ]).contains_exactly(standards)

    legacy = convert_feature_constraint(info)
    env.expect.that_collection(legacy.features).contains_exactly([])
    env.expect.that_collection(legacy.not_features).contains_exactly(standards)

def _c_std_features_test(env, targets):
    _check_std_features(
        env,
        feature_set = targets.all_c_std_features,
        category = targets.c_std,
        expected_flags = _gnu_flags(C_STANDARDS),
        actions = _C_ACTIONS,
    )

def _cpp_std_features_test(env, targets):
    _check_std_features(
        env,
        feature_set = targets.all_cpp_std_features,
        category = targets.cpp_std,
        expected_flags = _gnu_flags(CPP_STANDARDS),
        actions = _CPP_ACTIONS,
    )

def _msvc_c_std_features_test(env, targets):
    # MSVC variants must only use names that also exist for GCC/Clang so that
    # `features = ["c17"]` means the same thing everywhere.
    env.expect.that_collection(C_STANDARDS).contains_at_least(MSVC_C_STANDARDS.keys())
    _check_std_features(
        env,
        feature_set = targets.msvc_all_c_std_features,
        category = targets.c_std,
        expected_flags = _msvc_flags(MSVC_C_STANDARDS),
        actions = _C_ACTIONS,
    )

def _msvc_cpp_std_features_test(env, targets):
    env.expect.that_collection(CPP_STANDARDS).contains_at_least(MSVC_CPP_STANDARDS.keys())
    _check_std_features(
        env,
        feature_set = targets.msvc_all_cpp_std_features,
        category = targets.cpp_std,
        expected_flags = _msvc_flags(MSVC_CPP_STANDARDS),
        actions = _CPP_ACTIONS,
    )

def _feature_sets_and_constraints_test(env, targets):
    def names(feature_set):
        return [ft.name for ft in feature_set[FeatureSetInfo].features.to_list()]

    env.expect.that_collection(names(targets.all_std_features)).contains_exactly(C_STANDARDS + CPP_STANDARDS)
    env.expect.that_collection(names(targets.msvc_all_std_features)).contains_exactly(
        MSVC_C_STANDARDS.keys() + MSVC_CPP_STANDARDS.keys(),
    )

    _check_unspecified_constraint(env, targets.c_std_unspecified, C_STANDARDS)
    _check_unspecified_constraint(env, targets.cpp_std_unspecified, CPP_STANDARDS)
    _check_unspecified_constraint(env, targets.msvc_c_std_unspecified, MSVC_C_STANDARDS.keys())
    _check_unspecified_constraint(env, targets.msvc_cpp_std_unspecified, MSVC_CPP_STANDARDS.keys())

TARGETS = [
    ":msvc_all_c_std_features",
    ":msvc_all_cpp_std_features",
    ":msvc_all_std_features",
    ":msvc_c_std_unspecified",
    ":msvc_cpp_std_unspecified",
    "//cc/toolchains/args/std:all_c_std_features",
    "//cc/toolchains/args/std:all_cpp_std_features",
    "//cc/toolchains/args/std:all_std_features",
    "//cc/toolchains/args/std:c_std",
    "//cc/toolchains/args/std:cpp_std",
    "//cc/toolchains/args/std:c_std_unspecified",
    "//cc/toolchains/args/std:cpp_std_unspecified",
]

# @unsorted-dict-items
TESTS = {
    "c_std_features_test": _c_std_features_test,
    "cpp_std_features_test": _cpp_std_features_test,
    "msvc_c_std_features_test": _msvc_c_std_features_test,
    "msvc_cpp_std_features_test": _msvc_cpp_std_features_test,
    "feature_sets_and_constraints_test": _feature_sets_and_constraints_test,
}
