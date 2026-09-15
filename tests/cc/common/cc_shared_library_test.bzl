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

"""Tests for cc_shared_library linking modes."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@rules_testing//lib:truth.bzl", "matching", "subjects")
load("@rules_testing//lib:util.bzl", "util")
load("//cc:cc_library.bzl", "cc_library")
load("//cc:cc_shared_library.bzl", "cc_shared_library")
load("//cc/toolchains:cc_toolchain.bzl", "cc_toolchain")
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test")

def _test_link_staticness(name, toolchain, linkstatic, dynamic_mode, expected_static):
    util.helper_target(
        cc_library,
        name = name + "/leaf",
        srcs = ["leaf.cc"],
    )
    util.helper_target(
        cc_library,
        name = name + "/root",
        srcs = ["root.cc"],
        deps = [name + "/leaf"],
    )
    util.helper_target(
        cc_shared_library,
        name = name + "/shared",
        deps = [name + "/root"],
        **({} if linkstatic == None else {"linkstatic": linkstatic})
    )
    cc_analysis_test(
        name = name,
        impl = _test_link_staticness_impl,
        target = name + "/shared",
        config_settings = {
            "//command_line_option:dynamic_mode": dynamic_mode,
            "//command_line_option:extra_toolchains": str(toolchain),
            "//command_line_option:platforms": [Label("//tests/cc/testutil:linux_x86_64")],
        },
        test_features = ["supports_pic"],
        with_features = [
            "static_link_cpp_runtimes",
            "static_linking_mode",
            "dynamic_linking_mode",
            "supports_dynamic_linker",
            "supports_pic",
        ],
        attrs = {"expected_static": attr.bool()},
        attr_values = {"expected_static": expected_static},
    )

def _test_link_staticness_impl(env, target):
    assert_target = env.expect.that_target(target)
    link_action = assert_target.action_named("CppLink")
    expected_static = env.ctx.attr.expected_static
    link_action.env().get("linking_mode", factory = subjects.str).equals("static" if expected_static else "dynamic")

    # Direct deps must be embedded even when transitive deps and runtimes are dynamic.
    link_action.inputs().contains_predicate(matching.file_basename_equals("libroot.a"))
    link_action.inputs().not_contains_predicate(matching.file_basename_contains("libroot.so"))

    if expected_static:
        link_action.inputs().contains_predicate(matching.file_basename_equals("libstatic_runtime.a"))
        link_action.inputs().not_contains_predicate(matching.file_basename_equals("libdynamic_runtime.so"))
        link_action.inputs().contains_predicate(matching.file_basename_equals("libleaf.a"))
        link_action.inputs().not_contains_predicate(matching.file_basename_contains("libleaf.so"))
        assert_target.runfiles().not_contains_predicate(matching.str_endswith("/libdynamic_runtime.so"))
        assert_target.runfiles().not_contains_predicate(matching.str_endswith("libleaf.so"))
    else:
        link_action.inputs().contains_predicate(matching.file_basename_equals("libdynamic_runtime.so"))
        link_action.inputs().not_contains_predicate(matching.file_basename_equals("libstatic_runtime.a"))
        link_action.inputs().contains_predicate(matching.file_basename_contains("libleaf.so"))
        link_action.inputs().not_contains_predicate(matching.file_basename_equals("libleaf.a"))
        assert_target.runfiles().contains_predicate(matching.str_endswith("/libdynamic_runtime.so"))
        assert_target.runfiles().contains_predicate(matching.str_endswith("libleaf.so"))

def cc_shared_library_tests(name):
    """Tests the default, linkstatic values, and dynamic_mode overrides.

    Args:
        name: The name of the test suite.
    """
    tests = []
    if bazel_features.cc.cc_common_is_in_rules_cc:
        toolchain_name = name + "/toolchain"
        toolchain_files = "//tests/cc/testutil/toolchains:every-file"
        util.helper_target(
            cc_toolchain,
            name = name + "/compiler",
            all_files = toolchain_files,
            ar_files = toolchain_files,
            compiler_files = toolchain_files,
            linker_files = toolchain_files,
            strip_files = toolchain_files,
            static_runtime_lib = "libstatic_runtime.a",
            dynamic_runtime_lib = "libdynamic_runtime.so",
            toolchain_config = "//tests/cc/testutil/toolchains:k8-compiler_config",
        )
        util.helper_target(
            native.toolchain,
            name = toolchain_name,
            toolchain = name + "/compiler",
            toolchain_type = "//cc:toolchain_type",
        )
        for suffix, linkstatic, dynamic_mode, expected_static in [
            ("default", None, "default", True),
            ("static", True, "default", True),
            ("dynamic", False, "default", False),
            ("fully_overrides_static", True, "fully", False),
            ("off_overrides_dynamic", False, "off", True),
        ]:
            test_name = name + "_" + suffix
            _test_link_staticness(
                name = test_name,
                toolchain = Label(":" + toolchain_name),
                linkstatic = linkstatic,
                dynamic_mode = dynamic_mode,
                expected_static = expected_static,
            )
            tests.append(test_name)
    native.test_suite(name = name, tests = tests)
