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

"""Tests for find_cc_toolchain."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:truth.bzl", "matching")
load("@rules_testing//lib:util.bzl", "util")
load("//cc:find_cc_toolchain.bzl", "CC_TOOLCHAIN_TYPE", "find_cc_toolchain", "use_cc_toolchain")

def _missing_cc_provider_impl(_ctx):
    return [platform_common.ToolchainInfo(cc = None, cc_provider_in_toolchain = True)]

_missing_cc_provider = rule(implementation = _missing_cc_provider_impl)

def _find_cc_toolchain_impl(ctx):
    if find_cc_toolchain(ctx, mandatory = ctx.attr.mandatory) != None:
        fail("Expected no C++ toolchain")
    return []

_find_cc_toolchain = rule(
    implementation = _find_cc_toolchain_impl,
    attrs = {"mandatory": attr.bool(mandatory = True)},
    fragments = ["platform"],
    toolchains = use_cc_toolchain(),
)

def _expect_missing_provider(env, targets):
    env.expect.that_target(targets.optional).failures().contains_exactly([])
    env.expect.that_target(targets.mandatory).failures().contains_predicate(
        matching.contains("Unable to find a CC toolchain using toolchain resolution"),
    )

def find_cc_toolchain_missing_provider_test(name):
    """Tests C++ toolchain lookup with a missing provider.

    Args:
        name: Test target name.
    """
    util.helper_target(_missing_cc_provider, name = name + "_implementation")
    util.helper_target(
        native.toolchain,
        name = name + "_toolchain",
        toolchain = name + "_implementation",
        toolchain_type = CC_TOOLCHAIN_TYPE,
    )
    util.helper_target(_find_cc_toolchain, name = name + "_mandatory", mandatory = True)
    util.helper_target(_find_cc_toolchain, name = name + "_optional", mandatory = False)
    analysis_test(
        name = name,
        impl = _expect_missing_provider,
        targets = {
            "mandatory": name + "_mandatory",
            "optional": name + "_optional",
        },
        expect_failure = True,
        config_settings = {
            "//command_line_option:extra_toolchains": [str(native.package_relative_label(name + "_toolchain"))],
        },
    )
