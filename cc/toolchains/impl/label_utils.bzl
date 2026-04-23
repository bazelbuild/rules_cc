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
"""Helpers for passing possibly duplicated labels through rule attributes."""

def deduplicate_label_list(name, labels):
    """Deduplicates a label list while preserving the original indexes.

    Args:
        name: Name of the macro target using this helper.
        labels: Labels to normalize and deduplicate.

    Returns:
        A struct with deduplicated labels and original-to-deduplicated indexes.
    """
    deduplicated_labels = {}
    index_for_label = []

    for label in labels:
        package_relative_label = native.package_relative_label(label)
        if package_relative_label not in deduplicated_labels:
            deduplicated_labels[package_relative_label] = len(deduplicated_labels)
        index_for_label.append(deduplicated_labels[package_relative_label])

    return struct(
        labels = deduplicated_labels.keys(),
        indexes = index_for_label,
    )
