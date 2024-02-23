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
    "//cc/toolchains/impl:collect.bzl",
    "collect_args_lists",
)
load(":cc_toolchain_info.bzl", "ArgsListInfo")

def _cc_args_list_impl(ctx):
    return [collect_args_lists(ctx.attr.args, ctx.label)]

cc_args_list = rule(
    implementation = _cc_args_list_impl,
    doc = "A list of cc_args",
    attrs = {
        "args": attr.label_list(
            providers = [ArgsListInfo],
            doc = "The cc_args to include",
        ),
    },
    provides = [ArgsListInfo],
)
