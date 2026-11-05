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

"""Rules that allow select() to differentiate between C standard libraries and their versions."""

load("//cc:find_cc_toolchain.bzl", "CC_TOOLCHAIN_ATTRS", "find_cpp_toolchain", "use_cc_toolchain")
load("//cc/toolchains/impl:libc_version.bzl", "libc_version", "libc_without_version", "parse_libc_version")

_LibcInfo = provider(
    doc = "The C standard library targeted by the current C++ toolchain.",
    fields = {
        "name": "(str) The name of the C standard library without a version suffix.",
        "version": "(tuple[int] | None) The version of the C standard library, if known.",
    },
)

def _libc_flag_impl(ctx):
    libc = find_cpp_toolchain(ctx).libc
    name = libc_without_version(libc)
    return [
        config_common.FeatureFlagInfo(value = name),
        _LibcInfo(name = name, version = libc_version(libc)),
    ]

libc_flag = rule(
    implementation = _libc_flag_impl,
    attrs = CC_TOOLCHAIN_ATTRS,
    toolchains = use_cc_toolchain(),
)

def _libc_version_flag_impl(ctx):
    min_version = parse_libc_version(ctx.attr.min_version)
    if not min_version:
        fail("Invalid min_version {}, expected a version such as \"2.31\"".format(repr(ctx.attr.min_version)))
    libc = ctx.attr.libc[_LibcInfo]
    at_least = libc.name == ctx.attr.libc_name and libc.version != None and libc.version >= min_version
    return [config_common.FeatureFlagInfo(value = "true" if at_least else "false")]

libc_version_flag = rule(
    implementation = _libc_version_flag_impl,
    doc = """Provides "true" to config_setting.flag_values if the current C++ toolchain targets at
least the given version of a C standard library, as indicated by the version suffix of its
target_libc value, and "false" otherwise.""",
    attrs = {
        "libc": attr.label(
            doc = "The libc_flag target for the current C++ toolchain.",
            mandatory = True,
            providers = [_LibcInfo],
        ),
        "libc_name": attr.string(
            doc = "The name of the C standard library without a version suffix (e.g. \"glibc\").",
            mandatory = True,
        ),
        "min_version": attr.string(
            doc = "The minimum version of the C standard library (e.g. \"2.31\").",
            mandatory = True,
        ),
    },
)
