# Copyright 2024 The Bazel Authors. All rights reserved.
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
"""Test-only helper to apply a build setting override."""

load("//cc/toolchains:cc_toolchain_info.bzl", "ArgsInfo", "ArgsListInfo")

_MIN_OS_FLAG = "//tests/rule_based_toolchain/args:macos_min_os_flag"

def _override_min_os_transition_impl(_settings, attr):
    return {_MIN_OS_FLAG: attr.value}

_override_min_os_transition = transition(
    implementation = _override_min_os_transition_impl,
    inputs = [],
    outputs = [_MIN_OS_FLAG],
)

def _override_args_impl(ctx):
    target = ctx.attr.target
    if type(target) == "list":
        target = target[0]
    return [
        target[ArgsInfo],
        target[ArgsListInfo],
    ]

override_args = rule(
    implementation = _override_args_impl,
    attrs = {
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
        "target": attr.label(
            cfg = _override_min_os_transition,
            providers = [ArgsInfo],
            mandatory = True,
        ),
        "value": attr.string(mandatory = True),
    },
)
