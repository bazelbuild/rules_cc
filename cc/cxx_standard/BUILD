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

load("@bazel_skylib//rules:common_settings.bzl", "string_flag")
load("//cc/compiler:compilers.bzl", "COMPILERS")
load(":cxx_standard.bzl", "VERSIONS")

package(default_visibility = ["//visibility:public"])

licenses(["notice"])

string_flag(
    name = "cxx_standard",
    build_setting_default = "default",
    values = [
        "default",
        "none",
    ] + VERSIONS,
)

[
    config_setting(
        name = "cxx{}_{}".format(version, compiler),
        flag_values = {
            "//cc/private/toolchain:compiler": compiler,
            ":cxx_standard": version,
        },
    )
    for version in VERSIONS
    for compiler in COMPILERS
]

[
    config_setting(
        name = "cxx_default_{}".format(compiler),
        flag_values = {
            "//cc/private/toolchain:compiler": compiler,
            ":cxx_standard": "default",
        },
    )
    for compiler in COMPILERS
]
