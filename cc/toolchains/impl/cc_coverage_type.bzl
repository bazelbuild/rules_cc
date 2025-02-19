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

"""Rules to configure cc coverage types."""

load("//cc/toolchains:cc_toolchain_info.bzl", "CoverageTypeInfo")

# Users may not define their own types.
visibility([
    "//cc/coverage/type",
])

def _cc_coverage_type_impl(ctx):
    return [
        CoverageTypeInfo(
            label = ctx.label,
            name = ctx.attr.name,
        ),
    ]

cc_coverage_type = rule(
    implementation = _cc_coverage_type_impl,
    doc = """
Defines the a type for `cc_coverage_type`.
""",
    provides = [
        CoverageTypeInfo,
    ],
)
