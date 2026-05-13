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
"""Test helper for tool execution requirements."""

load("//cc/toolchains:providers.bzl", "ExecutionRequirementsInfo")

visibility("private")

def _test_execution_requirements_impl(ctx):
    return [
        ExecutionRequirementsInfo(
            label = ctx.label,
            requirements = tuple(ctx.attr.requirements),
        ),
    ]

test_execution_requirements = rule(
    implementation = _test_execution_requirements_impl,
    attrs = {
        "requirements": attr.string_list(),
    },
    provides = [ExecutionRequirementsInfo],
)
