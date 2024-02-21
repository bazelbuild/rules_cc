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
"""Helper functions to allow us to collect data from attr.label_list."""

load(
    "//cc/toolchains:cc_toolchain_info.bzl",
    "ActionTypeSetInfo",
)

visibility("//cc/toolchains/...")

def collect_provider(targets, provider):
    """Collects providers from a label list.

    Args:
        targets: (list[Target]) An attribute from attr.label_list
        provider: (provider) The provider to look up
    Returns:
        A list of the providers
    """
    return [target[provider] for target in targets]

def collect_defaultinfo(targets):
    """Collects DefaultInfo from a label list.

    Args:
        targets: (list[Target]) An attribute from attr.label_list
    Returns:
        A list of the associated defaultinfo
    """
    return collect_provider(targets, DefaultInfo)

def _make_collector(provider, field):
    def collector(targets, direct = [], transitive = []):
        # Avoid mutating what was passed in.
        transitive = transitive[:]
        for value in collect_provider(targets, provider):
            transitive.append(getattr(value, field))
        return depset(direct = direct, transitive = transitive)

    return collector

collect_action_types = _make_collector(ActionTypeSetInfo, "actions")
collect_files = _make_collector(DefaultInfo, "files")
