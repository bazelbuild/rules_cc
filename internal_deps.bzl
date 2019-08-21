# Copyright 2019 The Bazel Authors. All rights reserved.
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

"""Dependencies that are needed for rules_cc tests and tools."""

load("@bazel_federation//:repositories.bzl", "bazel_skylib", "protobuf", "rules_go")
load("@bazel_federation//:third_party_repositories.bzl", "abseil_py", "py_mock", "six", "zlib")

def rules_cc_internal_deps():
    """Fetches all required dependencies for rules_cc tests and tools."""
    bazel_skylib()
    protobuf()
    rules_go()

    abseil_py()
    py_mock()
    six()
    zlib()
