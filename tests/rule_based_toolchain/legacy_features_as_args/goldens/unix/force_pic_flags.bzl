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
"""Expected force_pic_flags legacy feature textproto on unix."""

visibility("private")

GOLDEN = """enabled: false
flag_sets {
  actions: "c++-link-executable"
  actions: "lto-index-for-executable"
  actions: "objc-executable"
  flag_groups {
    expand_if_available: "force_pic"
    flags: "-pie"
  }
}
name: "force_pic_flags_test"
"""
