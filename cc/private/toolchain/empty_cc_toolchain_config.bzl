# Copyright 2019 The Bazel Authors. All rights reserved.
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
"""A fake C++ toolchain configuration rule"""

load("@bazel_features//:features.bzl", "bazel_features")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/toolchains:cc_toolchain_config_info.bzl", "CcToolchainConfigInfo")

def _create_cc_toolchain_config_info(**kwargs):
    if not bazel_features.cc.cc_common_is_in_rules_cc:
        kwargs["toolchain_identifier"] = kwargs["ctx"].label.name
    return cc_common.create_cc_toolchain_config_info(**kwargs)

def _impl(ctx):
    out = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.write(out, "Fake executable")
    return [
        _create_cc_toolchain_config_info(
            ctx = ctx,
            host_system_name = "local",
            target_system_name = "local",
            target_cpu = "local",
            target_libc = "local",
            compiler = "compiler",
            abi_version = "local",
            abi_libc_version = "local",
        ),
        DefaultInfo(
            executable = out,
        ),
    ]

cc_toolchain_config = rule(
    implementation = _impl,
    attrs = {},
    provides = [CcToolchainConfigInfo],
    executable = True,
)
