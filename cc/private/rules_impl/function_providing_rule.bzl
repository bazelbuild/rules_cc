# Copyright 2020 The Bazel Authors. All rights reserved.
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

"""Trivially simple rule to provide a Starlark function via a target"""

visibility([
    "//third_party/bazel_rules/rules_cc/private/rules_impl",
])

FunctionInfo = provider("Wraps a Starlark function", fields = ["func"])

def wrap_starlark_function(func):
    return rule(
        implementation = lambda _unused_ctx: FunctionInfo(func = func),
        provides = [FunctionInfo],
    )

def proxy(ctx):
    return ctx.attr._impl_delegate[FunctionInfo].func(ctx)
