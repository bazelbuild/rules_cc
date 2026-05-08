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
"""Expected runtime_library_search_directories legacy feature textproto on macOS."""

visibility("private")

GOLDEN = """enabled: false
flag_sets {
  actions: "c++-link-dynamic-library"
  actions: "c++-link-executable"
  actions: "c++-link-nodeps-dynamic-library"
  actions: "lto-index-for-dynamic-library"
  actions: "lto-index-for-executable"
  actions: "lto-index-for-nodeps-dynamic-library"
  actions: "objc-executable"
  flag_groups {
    expand_if_available: "runtime_library_search_directories"
    flag_groups {
      flag_groups {
        expand_if_true: "is_cc_test"
        flags: "-Xlinker"
        flags: "-rpath"
        flags: "-Xlinker"
        flags: "$EXEC_ORIGIN/%{runtime_library_search_directories}"
      }
      flag_groups {
        expand_if_false: "is_cc_test"
        flags: "-Xlinker"
        flags: "-rpath"
        flags: "-Xlinker"
        flags: "@loader_path/%{runtime_library_search_directories}"
      }
      iterate_over: "runtime_library_search_directories"
    }
  }
  with_features {
    features: "static_link_cpp_runtimes"
  }
}
flag_sets {
  actions: "c++-link-dynamic-library"
  actions: "c++-link-executable"
  actions: "c++-link-nodeps-dynamic-library"
  actions: "lto-index-for-dynamic-library"
  actions: "lto-index-for-executable"
  actions: "lto-index-for-nodeps-dynamic-library"
  actions: "objc-executable"
  flag_groups {
    expand_if_available: "runtime_library_search_directories"
    flag_groups {
      flags: "-Xlinker"
      flags: "-rpath"
      flags: "-Xlinker"
      flags: "@loader_path/%{runtime_library_search_directories}"
      iterate_over: "runtime_library_search_directories"
    }
  }
  with_features {
    not_features: "static_link_cpp_runtimes"
  }
}
name: "runtime_library_search_directories_test"
"""
