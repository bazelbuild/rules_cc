# Copyright 2025 The Bazel Authors. All rights reserved.
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
"""GraphNodeInfo"""

GraphNodeInfo = provider(
    "Nodes in the graph of shared libraries.",
    fields = {
        "children": "Other GraphNodeInfo from dependencies of this target",
        "owners": "Owners of the linker inputs in the targets visited",
        "linkable_more_than_once": "Linkable into more than a single cc_shared_library",
    },  # buildifier: disable=unsorted-dict-items
)
