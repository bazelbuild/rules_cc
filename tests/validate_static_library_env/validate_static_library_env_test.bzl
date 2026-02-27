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
"""Analysis test for validate_static_library environment propagation."""

load("@bazel_features//private:util.bzl", _bazel_version_ge = "ge")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:util.bzl", "util")
load("//cc:cc_static_library.bzl", "cc_static_library")

def _validate_static_library_env_test_impl(env, target):
    env.expect.that_target(target).action_named("ValidateStaticLibrary").env().contains_at_least({
        "VALIDATE_STATIC_LIBRARY_ENV": "expected",
    })

def validate_static_library_env_test(name, target):
    analysis_test(
        name = name,
        target = target,
        impl = _validate_static_library_env_test_impl,
        config_settings = {
            "//command_line_option:extra_toolchains": [
                Label("//tests/validate_static_library_env:test_cc_toolchain_registration"),
            ],
            "//command_line_option:platforms": [
                Label("@rules_cc//tests/validate_static_library_env:test_platform"),
            ],
        },
    )

def maybe_define_validate_static_library_env_targets():
    # cc_static_library is implemented in rules_cc only for Bazel 9+.
    # For older Bazel versions, the native rule is used and does not wire
    # env vars from rules_cc toolchains for ValidateStaticLibrary.
    if not _bazel_version_ge("9.0.0-pre.20250911"):
        return

    util.helper_target(
        cc_static_library,
        name = "env_check_lib",
        deps = [],
    )

    validate_static_library_env_test(
        name = "validate_static_library_env_test",
        target = ":env_check_lib",
    )
