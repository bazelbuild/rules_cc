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

"""Tests for cc_binary with FDO."""

load("@rules_testing//lib:analysis_test.bzl", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching")
load("@rules_testing//lib:util.bzl", "util")
load("//cc:cc_binary.bzl", "cc_binary")
load("//cc/toolchains:fdo_profile.bzl", "fdo_profile")
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test")

def _test_fdo_profile_action_graph(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/foo",
        srcs = ["foo.cc"],
    )

    util.helper_target(
        fdo_profile,
        name = name + "/profile",
        profile = name + "/profile.profraw",
    )

    util.helper_target(
        native.genrule,
        name = name + "/gen_profraw",
        outs = [name + "/profile.profraw"],
        cmd = "touch $@",
    )

    cc_analysis_test(
        name = name,
        impl = _test_fdo_profile_action_graph_impl,
        targets = {
            "foo": name + "/foo",
            "gen_profraw": name + "/gen_profraw",
            "compiler": select({
                "@platforms//os:macos": "//tests/cc/testutil/toolchains:cc-compiler-macos-compiler",
                "//conditions:default": "//tests/cc/testutil/toolchains:cc-compiler-k8-compiler",
            }),
        },
        config_settings = {
            "//command_line_option:fdo_profile": Label(
                "//{package}:{name}/profile".format(
                    package = native.package_name(),
                    name = name,
                ),
            ),
            "//command_line_option:compilation_mode": "opt",
        },
        **kwargs
    )

def _test_fdo_profile_action_graph_impl(env, targets):
    # Verify the sequence of actions and inputs from the genrule producing the
    # raw profile to the final compile action.
    # Note that the {package} and {name} format strings are resolved for each
    # target differently; the compiler toolchain is in a different package
    # after all.
    assert_profraw_action = env.expect.that_target(targets.gen_profraw).action_named("Genrule")
    assert_profraw_action.outputs().contains_exactly([
        "{package}/{test_name}/profile.profraw",
    ])
    assert_profraw_symlink_action = env.expect.that_target(targets.compiler).action_generating(
        "{package}/fdo/{name}/profile.profraw",
    )
    assert_profraw_symlink_action.mnemonic().equals("Symlink")
    profraw_symlink = assert_profraw_symlink_action.actual.outputs.to_list()[0]

    assert_profdata_action = env.expect.that_target(targets.compiler).action_named("LLVMProfDataAction")
    assert_profdata_action.inputs().contains(
        profraw_symlink,
    )
    assert_profdata_action.outputs().contains_exactly([
        "{package}/fdo/{name}/profile.profdata",
    ])
    profdata = assert_profdata_action.actual.outputs.to_list()[0]

    assert_compile_action = env.expect.that_target(targets.foo).action_generating(
        "{package}/_objs/{name}/foo.o",
    )
    assert_compile_action.mnemonic().equals("CppCompile")
    assert_compile_action.argv().contains_predicate(
        matching.str_matches("-fprofile-use=*profile.profdata"),
    )

    # The configurations may not strictly line up due to how we referenced
    # these targets so just assert short_path
    assert_compile_action.inputs().contains(profdata.short_path)

def cc_binary_fdo_tests(name):
    test_suite(
        name = name,
        tests = [
            _test_fdo_profile_action_graph,
        ],
    )
