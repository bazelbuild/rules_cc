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
"""Expected compiler_input_flags legacy feature textproto on unix."""

visibility("private")

GOLDEN = """enabled: false
flag_sets {
  actions: "assemble"
  actions: "c++-compile"
  actions: "c++-module-codegen"
  actions: "c++-module-compile"
  actions: "c++-module-deps-scanning"
  actions: "c++20-module-codegen"
  actions: "c-compile"
  actions: "clif-match"
  actions: "linkstamp-compile"
  actions: "lto-backend"
  actions: "objc++-compile"
  actions: "objc-compile"
  actions: "preprocess-assemble"
  flag_groups {
    expand_if_available: "source_file"
    flags: "-c"
    flags: "%{source_file}"
  }
}
flag_sets {
  actions: "c++20-module-compile"
  flag_groups {
    expand_if_available: "source_file"
    flags: "-x"
    flags: "c++-module"
    flags: "-c"
    flags: "%{source_file}"
  }
}
flag_sets {
  actions: "c++-header-parsing"
  flag_groups {
    expand_if_available: "source_file"
    flags: "%{source_file}"
  }
}
name: "compiler_input_flags"
"""
