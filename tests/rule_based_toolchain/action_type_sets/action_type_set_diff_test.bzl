# Copyright 2026 The Bazel Authors. All rights reserved.
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
"""Test helper for cc_action_type_set validation."""

load("@bazel_skylib//rules:diff_test.bzl", "diff_test")
load("//cc/toolchains:cc_toolchain_info.bzl", "ActionTypeSetInfo")
load("//cc/toolchains/impl:collect.bzl", "collect_action_types")

visibility("private")

def _generate_action_type_set_impl(ctx):
    out = ctx.actions.declare_file(ctx.attr.output.name)
    actions = sorted([
        action.name
        for action in collect_action_types([ctx.attr.action_type_set]).to_list()
    ])
    ctx.actions.write(out, "\n".join(actions + [""]))
    return DefaultInfo(files = depset([out]))

_generate_action_type_set = rule(
    implementation = _generate_action_type_set_impl,
    attrs = {
        "action_type_set": attr.label(
            mandatory = True,
            providers = [ActionTypeSetInfo],
        ),
        "output": attr.output(mandatory = True),
    },
)

def action_type_set_diff_test(name, action_type_set, expected):
    output_filename = name + ".actual.txt"
    _generate_action_type_set(
        name = name + "_actual",
        action_type_set = action_type_set,
        output = output_filename,
        testonly = True,
    )
    diff_test(
        name = name,
        file1 = expected,
        file2 = output_filename,
    )
