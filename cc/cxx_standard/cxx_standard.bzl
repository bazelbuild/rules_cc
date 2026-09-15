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
"""Globals for C++ std version flags."""

load("//cc/compiler:compilers.bzl", "COMPILERS")

VERSIONS = [
    "98",
    "03",
    "11",
    "14",
    "17",
    "20",
    "23",
    "26",
    "2c",
]

def _flag(version, compiler):
    if compiler.startswith("msvc"):
        return "/std:c++{}".format(version)

    return "-std=c++{}".format(version)

def cxxopts(default = None):
    """Generate a select statement which contains the correct `stdcxx` flag for `cxxopts` attributes.

    Example:

    ```starlark
    load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
    load("@rules_cc//cc/cxx_standard:cxx_standard.bzl", "cxxopts")

    cc_binary(
        name = "foo",
        srcs = ["foo.cc"],
        cxxopts = cxxopts(default = "20") + [
            # Any additional cxxopts
        ],
    )
    ```

    Note that the `--@rules_cc//cc/cxx_standard` flag can be used to override specified `default` value.

    Args:
        default (str, optional): The default version of the C++ standard to use.

    Returns:
        select: A mapping of cxx version and compiler to the `cxxopts` flags.
    """
    default_branches = {}
    if default:
        if default not in VERSIONS:
            fail("Unexpected stdc++ version: {}".format(default))

        default_branches = {
            Label("//cc/cxx_standard:cxx_default_{}".format(compiler)): [_flag(default, compiler)]
            for compiler in COMPILERS
        }

    return select({
        Label("//cc/cxx_standard:cxx{}_{}".format(version, compiler)): [_flag(version, compiler)]
        for version in VERSIONS
        for compiler in COMPILERS
    } | default_branches | {
        "//conditions:default": [],
    })
