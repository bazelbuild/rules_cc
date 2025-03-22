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

"""Rules to turn make variable substitution into targets."""

load(":cc_toolchain_info.bzl", "MakeVariableInfo")

visibility("public")

def _cc_make_variable_impl(ctx):
    return [
        MakeVariableInfo(
            label = ctx.label,
            key = ctx.label.name,
            value = ctx.attr.value,
        ),
    ]

cc_make_variable = rule(
    implementation = _cc_make_variable_impl,
    attrs = {
        "value": attr.string(mandatory = True),
    },
    doc = """
This is used to declare that key / value substitutions for use in make-variable
substitutions in `copts` and other attributes.

Example:

```
load("//cc/toolchains:make_variables.bzl", "cc_make_variable")

cc_make_variable(
    name = "STACK_FRAME_UNLIMITED",
    value = "-Wframe-larger-than=100000000 -Wno-vla",
)
```
""",
    provides = [
        MakeVariableInfo,
    ],
)
