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

load(":default_test_runner.bzl", "compat_toolchain", "default_test_runner")

default_test_runner(name = "default_test_runner")

compat_toolchain(
    name = "default_test_runner_toolchain",
    toolchain = ":default_test_runner",
    toolchain_type = "@bazel_tools//tools/cpp:test_runner_toolchain_type",
    use_target_platform_constraints = True,
)
