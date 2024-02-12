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
"""All providers for rule-based bazel toolchain config."""

# Until the providers are stabilized, ensure that rules_cc is the only place
# that can access the providers directly.
# Once it's stabilized, we *may* consider opening up parts of the API, or we may
# decide to just require users to use the public user-facing rules.
visibility("//third_party/bazel_rules/rules_cc/toolchains/...")

# Note that throughout this file, we never use a list. This is because mutable
# types cannot be stored in depsets. Thus, we type them as a sequence in the
# provider, and convert them to a tuple in the constructor to ensure
# immutability.

ActionTypeInfo = provider(
    doc = "A type of action (eg. c-compile, c++-link-executable)",
    fields = {
        "label": "(Label) The label defining this provider. Place in error messages to simplify debugging",
        "name": "(str) The action name, as defined by action_names.bzl",
    },
)

ActionTypeSetInfo = provider(
    doc = "A set of types of actions",
    # @unsorted-dict-items
    fields = {
        "label": "(Label) The label defining this provider. Place in error messages to simplify debugging",
        "actions": "(depset[ActionTypeInfo]) Set of action types",
    },
)

FlagGroupInfo = provider(
    doc = "A group of flags",
    # @unsorted-dict-items
    fields = {
        "label": "(Label) The label defining this provider. Place in error messages to simplify debugging",
        "flags": "(Sequence[str]) A list of flags to add to the command-line",
    },
)

FlagSetInfo = provider(
    doc = "A set of flags to be expanded in the command line for specific actions",
    # @unsorted-dict-items
    fields = {
        "label": "(Label) The label defining this provider. Place in error messages to simplify debugging",
        "actions": "(depset[ActionTypeInfo]) The set of actions this is associated with",
        "requires_any_of": "(Sequence[FeatureConstraintInfo]) This will be enabled if any of the listed predicates are met. Equivalent to with_features",
        "flag_groups": "(Sequence[FlagGroupInfo]) Set of flag groups to include.",
    },
)

FeatureInfo = provider(
    doc = "Contains all flag specifications for one feature.",
    # @unsorted-dict-items
    fields = {
        "label": "(Label) The label defining this provider. Place in error messages to simplify debugging",
        "name": "(str) The name of the feature",
        "enabled": "(bool) Whether this feature is enabled by default",
        "flag_sets": "(depset[FlagSetInfo]) Flag sets enabled by this feature",
        "implies": "(depset[FeatureInfo]) Set of features implied by this feature",
        "requires_any_of": "(Sequence[FeatureSetInfo]) A list of feature sets, at least one of which is required to enable this feature. This is semantically equivalent to the requires attribute of rules_cc's FeatureInfo",
        "provides": "(Sequence[MutuallyExclusiveCategoryInfo]) Indicates that this feature is one of several mutually exclusive alternate features.",
        "known": "(bool) Whether the feature is a known feature. Known features are assumed to be defined elsewhere.",
        "overrides": "(Optional[FeatureInfo]) The feature that this overrides",
    },
)
FeatureSetInfo = provider(
    doc = "A set of features",
    # @unsorted-dict-items
    fields = {
        "label": "(Label) The label defining this provider. Place in error messages to simplify debugging",
        "features": "(depset[FeatureInfo]) The set of features this corresponds to",
    },
)

FeatureConstraintInfo = provider(
    doc = "A predicate checking that certain features are enabled and others disabled.",
    # @unsorted-dict-items
    fields = {
        "label": "(Label) The label defining this provider. Place in error messages to simplify debugging",
        "all_of": "(depset[FeatureInfo]) A set of features which must be enabled",
        "none_of": "(depset[FeatureInfo]) A set of features, none of which can be enabled",
    },
)

MutuallyExclusiveCategoryInfo = provider(
    doc = "Multiple features with the category will be mutally exclusive",
    fields = {
        "label": "(Label) The label defining this provider. Place in error messages to simplify debugging",
        "name": "(str) The name of the category",
    },
)

ToolInfo = provider(
    doc = "A binary, with additional metadata to make it useful for action configs.",
    # @unsorted-dict-items
    fields = {
        "label": "(Label) The label defining this provider. Place in error messages to simplify debugging",
        "exe": "(Optional[File]) The file corresponding to the tool",
        "runfiles": "(depset[File]) The files required to run the tool",
        "requires_any_of": "(Sequence[FeatureConstraintInfo]) A set of constraints, one of which is required to enable the tool. Equivalent to with_features",
        "execution_requirements": "(Sequence[str]) A set of execution requirements of the tool",
    },
)

ActionConfigInfo = provider(
    doc = "Configuration of a Bazel action.",
    # @unsorted-dict-items
    fields = {
        "label": "(Label) The label defining this provider. Place in error messages to simplify debugging",
        "action_name": "(str) The name of the action",
        "enabled": "(bool) If True, this action is enabled unless a rule type explicitly marks it as unsupported",
        "tools": "(Sequence[ToolInfo]) The tool applied to the action will be the first tool in the sequence with a feature set that matches the feature configuration",
        "flag_sets": "(depset[FlagSetInfo]) Set of flag sets the action sets",
        "implies_features": "(depset[FeatureInfo]) Set of features implied by this action config",
        "implies_action_configs": "(depset[ActionConfigInfo]) Set of action configs enabled by this action config",
        "files": "(depset[File]) The files required to run these actions",
    },
)

ActionConfigSetInfo = provider(
    doc = "A set of action configs",
    # @unsorted-dict-items
    fields = {
        "label": "(Label) The label defining this provider. Place in error messages to simplify debugging",
        "action_configs": "(depset[ActionConfigInfo]) A set of action configs",
    },
)
