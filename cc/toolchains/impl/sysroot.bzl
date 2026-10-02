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
"""Automatic sysroot metadata collection for rule-based toolchains."""

load("//cc/toolchains:cc_toolchain_info.bzl", "ArgsInfo", "ArgsListInfo", "CcSysrootInfo", "FeatureSetInfo")

visibility([
    "//cc/toolchains/...",
    "//tests/rule_based_toolchain/...",
])

def _sysroot_aspect_impl(target, ctx):
    if CcSysrootInfo in target:
        return []

    deps = getattr(ctx.rule.attr, "args", []) + getattr(ctx.rule.attr, "all_of", [])
    return [CcSysrootInfo(sysroots = depset(transitive = [
        dep[CcSysrootInfo].sysroots
        for dep in deps
        if type(dep) == "Target" and CcSysrootInfo in dep
    ]))]

sysroot_aspect = aspect(
    implementation = _sysroot_aspect_impl,
    attr_aspects = ["args", "all_of"],
    required_providers = [[ArgsInfo], [ArgsListInfo], [FeatureSetInfo]],
)

def get_sysroot(targets, sysroot_path = "", fail = fail):
    """Resolves automatically collected sysroots, honoring a literal override.

    Args:
        targets: Toolchain args and feature targets with collected CcSysrootInfo.
        sysroot_path: A nonempty literal path takes precedence over all collected paths.
        fail: A fail function. Use only during tests.

    Returns:
        The sysroot path, or None if no sysroot was declared.
    """
    if sysroot_path:
        return sysroot_path

    sysroots = depset(transitive = [
        target[CcSysrootInfo].sysroots
        for target in targets
        if CcSysrootInfo in target
    ])
    paths = {sysroot.path: str(sysroot.label) for sysroot in sysroots.to_list()}
    if len(paths) > 1:
        fail("Multiple cc_sysroot were found in this toolchain: %s. Use select() to choose a single sysroot or set sysroot_path to override." % paths)

    return paths.keys()[0] if paths else None
