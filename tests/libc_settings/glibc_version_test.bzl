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

"""Tests for the glibc version config settings in //cc/libc."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("//cc:cc_library.bzl", "cc_library")
load("//cc/common:cc_info.bzl", "CcInfo")
load("//cc/private/toolchain:unix_cc_toolchain_config.bzl", "cc_toolchain_config")  # buildifier: disable=bzl-visibility
load("//cc/toolchains:cc_toolchain.bzl", "cc_toolchain")
load("//cc/toolchains/impl:libc_version.bzl", "GLIBC_VERSIONS")

def glibc_at_least_minor_defines(glibc_without_level = [], default = []):
    """Returns a select() over all glibc version config settings.

    Args:
        glibc_without_level: The defines if the toolchain targets glibc, but none of the
            version settings match.
        default: The defines if the toolchain doesn't target glibc.

    Returns:
        A select() that results in GLIBC_AT_LEAST_MINOR=<minor version> for the most specific
        matching version setting.
    """
    conditions = {
        Label("//cc/libc:glibc_at_least_" + version): ["GLIBC_AT_LEAST_MINOR=" + version.split(".")[1]]
        for version in GLIBC_VERSIONS
    }
    conditions[Label("//cc/libc:glibc")] = glibc_without_level
    conditions["//conditions:default"] = default
    return select(conditions)

# The target_libc values of the mock toolchains and the define each of them is expected to result
# in.
_CASES = {
    "glibc": "GLIBC_WITHOUT_LEVEL",
    "glibc-2.14": "GLIBC_WITHOUT_LEVEL",
    "glibc-2.15": "GLIBC_AT_LEAST_MINOR=15",
    "glibc-2.33": "GLIBC_AT_LEAST_MINOR=33",
    "glibc-2.33.1": "GLIBC_AT_LEAST_MINOR=33",
    "glibc-2.44": "GLIBC_AT_LEAST_MINOR=44",
    # Versions newer than the highest one with a setting match all settings.
    "glibc-2.99": "GLIBC_AT_LEAST_MINOR=44",
    "glibc-2.33-vendor": "GLIBC_WITHOUT_LEVEL",
    "musl-1.2.4": "NOT_GLIBC",
}

def _mock_toolchain(name, target_libc):
    cc_toolchain_config(
        name = name + "_config",
        abi_libc_version = "local",
        abi_version = "local",
        compiler = "compiler",
        cpu = "k8",
        host_system_name = "local",
        target_libc = target_libc,
        target_system_name = "local",
        tool_paths = {
            "ar": "/usr/bin/ar",
            "cpp": "/usr/bin/cpp",
            "gcc": "/usr/bin/gcc",
            "ld": "/usr/bin/ld",
            "nm": "/usr/bin/nm",
            "objcopy": "/usr/bin/objcopy",
            "objdump": "/usr/bin/objdump",
            "strip": "/usr/bin/strip",
        },
        toolchain_identifier = name,
    )

    cc_toolchain(
        name = name + "_cc_toolchain",
        all_files = ":empty",
        ar_files = ":empty",
        as_files = ":empty",
        compiler_files = ":empty",
        dwp_files = ":empty",
        linker_files = ":empty",
        objcopy_files = ":empty",
        strip_files = ":empty",
        toolchain_config = name + "_config",
        toolchain_identifier = name,
    )

    native.toolchain(
        name = name,
        target_compatible_with = ["@platforms//os:linux"],
        toolchain = name + "_cc_toolchain",
        toolchain_type = "//cc:toolchain_type",
    )

def _glibc_version_test_impl(env, target):
    env.expect.that_collection(
        target[CcInfo].compilation_context.defines.to_list(),
    ).contains_exactly([env.ctx.attr.expected_define])

def glibc_version_test_suite(name):
    """Tests the glibc version config settings with mock toolchains.

    Args:
        name: The name of the test suite.
    """
    native.platform(
        name = name + "_linux",
        constraint_values = ["@platforms//os:linux"],
    )

    native.filegroup(
        name = "empty",
    )

    cc_library(
        name = name + "_subject",
        defines = glibc_at_least_minor_defines(
            glibc_without_level = ["GLIBC_WITHOUT_LEVEL"],
            default = ["NOT_GLIBC"],
        ),
        tags = ["manual"],
    )

    tests = []
    for target_libc, expected_define in _CASES.items():
        toolchain_name = "{}_{}_toolchain".format(name, target_libc)
        _mock_toolchain(
            name = toolchain_name,
            target_libc = target_libc,
        )

        # Analysis test names have to be Starlark identifiers.
        test_name = "{}_{}".format(name, target_libc.replace("-", "_").replace(".", "_"))
        analysis_test(
            name = test_name,
            impl = _glibc_version_test_impl,
            target = name + "_subject",
            attrs = {"expected_define": attr.string()},
            attr_values = {"expected_define": expected_define},
            config_settings = {
                "//command_line_option:extra_toolchains": [str(Label(":" + toolchain_name))],
                "//command_line_option:platforms": [str(Label(":" + name + "_linux"))],
            },
        )
        tests.append(test_name)

    native.test_suite(
        name = name,
        tests = tests,
    )
