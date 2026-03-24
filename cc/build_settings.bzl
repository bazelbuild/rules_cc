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
    "incompatible_strip_executable_safely": (lambda ctx: ctx.fragments.objc.strip_executable_safely, "native"),
}

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

    # Bazel can disable the native fragment with --incompatible_remove_ctx_objc_fragment. Disabling
    # them means bazel expects consumers to read the Starlark flags.
    use_native_def = hasattr(ctx.fragments, "objc")

    # Override to force the Starlark definition for testing/flipping flags one at a time.
    if _POSSIBLY_NATIVE_FLAGS[flag_name][1] == "starlark":
        use_native_def = False
    if use_native_def:
        return _POSSIBLY_NATIVE_FLAGS[flag_name][0](ctx)

    # Starlark definition of "--foo" is assumed to be a label dependency named "_foo".
    return getattr(ctx.attr, "_" + flag_name)[BuildSettingInfo].value

cc = struct(
    read_possibly_native_flag = _read_possibly_native_flag,
)
