# Copyright 2024 The Bazel Authors. All rights reserved.
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
"""All providers for rule-based bazel toolchain config."""

load(
    "//cc/toolchains/impl:nested_args.bzl",
    "NESTED_ARGS_ATTRS",
    "args_wrapper_macro",
    "nested_args_provider_from_ctx",
)
load(
    ":cc_toolchain_info.bzl",
    "NestedArgsInfo",
)

visibility("public")

_cc_nested_args = rule(
    implementation = lambda ctx: [nested_args_provider_from_ctx(ctx)],
    attrs = NESTED_ARGS_ATTRS,
    provides = [NestedArgsInfo],
    doc = """Declares a list of arguments bound to a set of actions.

Roughly equivalent to ctx.actions.args()

Examples:
    cc_nested_args(
        name = "warnings_as_errors",
        args = ["-Werror"],
    )
""",
)

cc_nested_args = lambda **kwargs: args_wrapper_macro(rule = _cc_nested_args, **kwargs)
