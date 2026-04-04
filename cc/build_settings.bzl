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

"""List of Bazel's rules_cc build settings."""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

_POSSIBLY_NATIVE_FLAGS = {
    "incompatible_disallow_sdk_frameworks_attributes": (lambda ctx: ctx.fragments.objc.disallow_sdk_frameworks_attributes, "native"),
    "incompatible_objc_alwayslink_by_default": (lambda ctx: ctx.fragments.objc.alwayslink_by_default, "native"),
    "incompatible_strip_executable_safely": (lambda ctx: ctx.fragments.objc.strip_executable_safely, "native"),
}

def _use_native_def(ctx, flag_name):
    """Returns True if the native fragment should be used for the given flag."""

    # Bazel can disable the native fragment with --incompatible_remove_ctx_objc_fragment. Disabling
    # them means bazel expects consumers to read the Starlark flags.
    if not hasattr(ctx.fragments, "objc"):
        return False

    # Override to force the Starlark definition for testing/flipping flags one at a time.
    if _POSSIBLY_NATIVE_FLAGS[flag_name][1] == "starlark":
        return False

    return True

def _read_starlark_flag(ctx, flag_name):
    """Reads a rules_cc build flag from its Starlark definition."""

    # Starlark definition of "--foo" is assumed to be a label dependency named "_foo".
    return getattr(ctx.attr, "_" + flag_name)[BuildSettingInfo].value

def _read_possibly_native_flag(ctx, flag_name):
    """Canonical API for reading a rules_cc build flag.

    Flags might be defined in Starlark or native-Bazel. This function reads flags
    from the correct source based on supporting Bazel version and --incompatible*
    flags that disable native references.

    Args:
        ctx: Rule's configuration context.
        flag_name: Name of the flag to read, without preceding "--".

    Returns:
        The flag's value.
    """

    if _use_native_def(ctx, flag_name):
        return _POSSIBLY_NATIVE_FLAGS[flag_name][0](ctx)

    return _read_starlark_flag(ctx, flag_name)

def _target_should_alwayslink(ctx):
    """Replicates native ObjcConfiguration.targetShouldAlwayslink logic."""
    flag_name = "incompatible_objc_alwayslink_by_default"
    if _use_native_def(ctx, flag_name):
        return ctx.fragments.objc.target_should_alwayslink(ctx)

    if hasattr(ctx.attr, "alwayslink") and getattr(ctx.attr, "_alwayslink_explicitly_set", False):
        return ctx.attr.alwayslink

    return _read_starlark_flag(ctx, flag_name)

cc = struct(
    read_possibly_native_flag = _read_possibly_native_flag,
    target_should_alwayslink = _target_should_alwayslink,
)
