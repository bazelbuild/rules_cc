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
"""Test subjects for cc_toolchain_info providers."""

load("@bazel_skylib//lib:structs.bzl", "structs")
load("@rules_testing//lib:truth.bzl", _subjects = "subjects")
load(
    "//cc/toolchains:cc_toolchain_info.bzl",
    "ActionTypeConfigInfo",
    "ActionTypeConfigSetInfo",
    "ActionTypeInfo",
    "ActionTypeSetInfo",
    "ArgsInfo",
    "ArgsListInfo",
    "FeatureConstraintInfo",
    "FeatureInfo",
    "FeatureSetInfo",
    "MutuallyExclusiveCategoryInfo",
    "NestedArgsInfo",
    "ToolInfo",
    "ToolchainConfigInfo",
)
load(":generate_factory.bzl", "ProviderDepset", "ProviderSequence", "generate_factory")
load(":generics.bzl", "dict_key_subject", "optional_subject", "result_subject", "struct_subject", _result_fn_wrapper = "result_fn_wrapper")

visibility("//tests/rule_based_toolchain/...")

# The default runfiles subject uses path instead of short_path.
# This makes it rather awkward for copybara.
runfiles_subject = lambda value, meta: _subjects.depset_file(value.files, meta = meta)

# The string type has .equals(), which is all we can really do for an unknown
# type.
unknown_subject = _subjects.str

# buildifier: disable=name-conventions
_ActionTypeFactory = generate_factory(
    ActionTypeInfo,
    "ActionTypeInfo",
    dict(
        name = _subjects.str,
    ),
)

# buildifier: disable=name-conventions
_ActionTypeSetFactory = generate_factory(
    ActionTypeSetInfo,
    "ActionTypeInfo",
    dict(
        actions = ProviderDepset(_ActionTypeFactory),
    ),
)

# buildifier: disable=name-conventions
_MutuallyExclusiveCategoryFactory = generate_factory(
    MutuallyExclusiveCategoryInfo,
    "MutuallyExclusiveCategoryInfo",
    dict(name = _subjects.str),
)

_FEATURE_FLAGS = dict(
    name = _subjects.str,
    enabled = _subjects.bool,
    args = None,
    implies = None,
    requires_any_of = None,
    mutually_exclusive = ProviderSequence(_MutuallyExclusiveCategoryFactory),
    overridable = _subjects.bool,
    external = _subjects.bool,
    overrides = None,
)

# Break the dependency loop.
# buildifier: disable=name-conventions
_FakeFeatureFactory = generate_factory(
    FeatureInfo,
    "FeatureInfo",
    _FEATURE_FLAGS,
)

# buildifier: disable=name-conventions
_FeatureSetFactory = generate_factory(
    FeatureSetInfo,
    "FeatureSetInfo",
    dict(features = ProviderDepset(_FakeFeatureFactory)),
)

# buildifier: disable=name-conventions
_FeatureConstraintFactory = generate_factory(
    FeatureConstraintInfo,
    "FeatureConstraintInfo",
    dict(
        all_of = ProviderDepset(_FakeFeatureFactory),
        none_of = ProviderDepset(_FakeFeatureFactory),
    ),
)

_NESTED_ARGS_FLAGS = dict(
    nested = None,
    files = _subjects.depset_file,
    iterate_over = optional_subject(_subjects.str),
    legacy_flag_group = unknown_subject,
    requires_types = _subjects.dict,
    unwrap_options = _subjects.collection,
)

# buildifier: disable=name-conventions
_FakeNestedArgsFactory = generate_factory(
    NestedArgsInfo,
    "NestedArgsInfo",
    _NESTED_ARGS_FLAGS,
)

# buildifier: disable=name-conventions
_NestedArgsFactory = generate_factory(
    NestedArgsInfo,
    "NestedArgsInfo",
    _NESTED_ARGS_FLAGS | dict(
        nested = ProviderSequence(_FakeNestedArgsFactory),
    ),
)

# buildifier: disable=name-conventions
_ArgsFactory = generate_factory(
    ArgsInfo,
    "ArgsInfo",
    dict(
        actions = ProviderDepset(_ActionTypeFactory),
        env = _subjects.dict,
        files = _subjects.depset_file,
        # Use .factory so it's not inlined.
        nested = optional_subject(_NestedArgsFactory.factory),
        requires_any_of = ProviderSequence(_FeatureConstraintFactory),
    ),
)

# buildifier: disable=name-conventions
_ArgsListFactory = generate_factory(
    ArgsListInfo,
    "ArgsListInfo",
    dict(
        args = ProviderSequence(_ArgsFactory),
        by_action = lambda values, *, meta: dict_key_subject(struct_subject(
            args = _subjects.collection,
            files = _subjects.depset_file,
        ))({value.action: value for value in values}, meta = meta),
        files = _subjects.depset_file,
    ),
)

# buildifier: disable=name-conventions
_FeatureFactory = generate_factory(
    FeatureInfo,
    "FeatureInfo",
    _FEATURE_FLAGS | dict(
        # Use .factory so it's not inlined.
        args = _ArgsListFactory.factory,
        implies = ProviderDepset(_FakeFeatureFactory),
        requires_any_of = ProviderSequence(_FeatureSetFactory),
        overrides = optional_subject(_FakeFeatureFactory.factory),
    ),
)

# buildifier: disable=name-conventions
_ToolFactory = generate_factory(
    ToolInfo,
    "ToolInfo",
    dict(
        exe = _subjects.file,
        runfiles = runfiles_subject,
        requires_any_of = ProviderSequence(_FeatureConstraintFactory),
        execution_requirements = _subjects.collection,
    ),
)

# buildifier: disable=name-conventions
_ActionTypeConfigFactory = generate_factory(
    ActionTypeConfigInfo,
    "ActionTypeConfigInfo",
    dict(
        action_type = _ActionTypeFactory,
        tools = ProviderSequence(_ToolFactory),
        args = ProviderSequence(_ArgsFactory),
        implies = ProviderDepset(_FeatureFactory),
        files = runfiles_subject,
    ),
)

# buildifier: disable=name-conventions
_ActionTypeConfigSetFactory = generate_factory(
    ActionTypeConfigSetInfo,
    "ActionTypeConfigSetInfo",
    dict(
        configs = dict_key_subject(_ActionTypeConfigFactory.factory),
    ),
)

# buildifier: disable=name-conventions
_ToolchainConfigFactory = generate_factory(
    ToolchainConfigInfo,
    "ToolchainConfigInfo",
    dict(
        features = ProviderDepset(_FeatureFactory),
        action_type_configs = dict_key_subject(_ActionTypeConfigFactory.factory),
        args = ProviderSequence(_ArgsFactory),
        files = dict_key_subject(_subjects.depset_file),
    ),
)

FACTORIES = [
    _ActionTypeFactory,
    _ActionTypeSetFactory,
    _NestedArgsFactory,
    _ArgsFactory,
    _ArgsListFactory,
    _MutuallyExclusiveCategoryFactory,
    _FeatureFactory,
    _FeatureConstraintFactory,
    _FeatureSetFactory,
    _ToolFactory,
    _ActionTypeConfigSetFactory,
    _ToolchainConfigFactory,
]

result_fn_wrapper = _result_fn_wrapper

subjects = struct(
    **(structs.to_dict(_subjects) | dict(
        unknown = unknown_subject,
        result = result_subject,
        optional = optional_subject,
        struct = struct_subject,
        runfiles = runfiles_subject,
        dict_key = dict_key_subject,
    ) | {factory.name: factory.factory for factory in FACTORIES})
)
