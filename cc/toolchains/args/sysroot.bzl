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
"""Implementation of the cc_sysroot macro."""

load("@bazel_skylib//rules/directory:providers.bzl", "DirectoryInfo")
load("//cc/toolchains:cc_toolchain_info.bzl", "ArgsInfo", "ArgsListInfo", "CcSysrootInfo")
load(
    "//cc/toolchains/impl:args.bzl",
    _CC_ARGS_ATTRS = "CC_ARGS_ATTRS",
    _cc_args_impl = "cc_args_impl",
)

visibility("public")

_DEFAULT_SYSROOT_ACTIONS = [
    Label("//cc/toolchains/actions:assembly_actions"),
    Label("//cc/toolchains/actions:c_compile"),
    Label("//cc/toolchains/actions:objc_compile"),
    Label("//cc/toolchains/actions:cpp_compile_actions"),
    Label("//cc/toolchains/actions:link_actions"),
]

def _cc_sysroot_impl(ctx):
    return _cc_args_impl(ctx) + [CcSysrootInfo(sysroots = depset([
        struct(label = ctx.label, path = ctx.attr.sysroot[DirectoryInfo].path),
    ]))]

_cc_sysroot = rule(
    implementation = _cc_sysroot_impl,
    attrs = {
        "sysroot": attr.label(providers = [DirectoryInfo], mandatory = True),
    } | _CC_ARGS_ATTRS,
    provides = [ArgsInfo, ArgsListInfo, CcSysrootInfo],
)

def cc_sysroot(*, name, sysroot, actions = _DEFAULT_SYSROOT_ACTIONS, args = [], **kwargs):
    """Declares a toolchain's sysroot and the arguments and inputs needed to use it.

    Adding this target to a toolchain's args, directly or through a `cc_args_list`
    or `cc_feature`, automatically sets `CcToolchainInfo.sysroot`. The directory's
    files are included by default; pass `data = []` to omit them, or provide a
    custom `data` list.

    All collected sysroots must have the same path, including those in features
    that are disabled. A nonempty `cc_toolchain.sysroot_path` silently overrides
    the collected paths without changing this target's arguments or inputs.

    Args:
      name: (str) The name of the target
      sysroot: (bazel_skylib's directory rule) The directory that should be the
        sysroot.
      actions: (List[Label]) Actions the `--sysroot` flag should be applied to.
      args: (List[str]) Extra command-line args to add.
      **kwargs: kwargs to pass to cc_args.
    """
    if "data" not in kwargs:
        kwargs["data"] = [sysroot]

    _cc_sysroot(
        name = name,
        sysroot = sysroot,
        actions = actions,
        args = ["--sysroot={sysroot}"] + args,
        format = {sysroot: "sysroot"},
        **kwargs
    )
