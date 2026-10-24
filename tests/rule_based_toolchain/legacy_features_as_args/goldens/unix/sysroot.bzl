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
"""Expected sysroot legacy feature textproto on unix."""

visibility("private")

GOLDEN = """enabled: false
flag_sets {
  actions: "assemble"
  actions: "c++-compile"
  actions: "c++-header-parsing"
  actions: "c++-link-dynamic-library"
  actions: "c++-link-executable"
  actions: "c++-link-nodeps-dynamic-library"
  actions: "c++-module-codegen"
  actions: "c++-module-compile"
  actions: "c++-module-deps-scanning"
  actions: "c++20-module-codegen"
  actions: "c++20-module-compile"
  actions: "c-compile"
  actions: "clif-match"
  actions: "linkstamp-compile"
  actions: "lto-backend"
  actions: "lto-index-for-dynamic-library"
  actions: "lto-index-for-executable"
  actions: "lto-index-for-nodeps-dynamic-library"
  actions: "objc++-compile"
  actions: "objc-compile"
  actions: "objc-executable"
  actions: "preprocess-assemble"
  flag_groups {
    flags: "--sysroot=%{path:tests/rule_based_toolchain/testdata}"
  }
}
name: "sysroot_test"
"""
