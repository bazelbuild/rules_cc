# Copyright 2021 The Bazel Authors. All rights reserved.
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

"""cc_test Starlark implementation."""

load("//cc/common:cc_helper.bzl", "cc_helper")
load("//cc/common:semantics.bzl", "semantics")
load(":cc_binary_impl.bzl", "cc_binary_impl")
load(":function_providing_rule.bzl", "wrap_starlark_function")

_CC_TEST_TOOLCHAIN_TYPE = "@bazel_tools//tools/cpp:test_runner_toolchain_type"

def _legacy_cc_test_impl(ctx):
    binary_info, providers = cc_binary_impl(ctx, [])
    test_env = {}
    test_env.update(cc_helper.get_expanded_env(ctx, {}))

    coverage_runfiles, coverage_env = semantics.get_coverage_env(ctx)

    runfiles_list = [binary_info.runfiles]
    if coverage_runfiles:
        runfiles_list.append(coverage_runfiles)

    runfiles = ctx.runfiles()
    runfiles = runfiles.merge_all(runfiles_list)

    test_env.update(coverage_env)
    providers.append(testing.TestEnvironment(
        environment = test_env,
        inherited_environment = ctx.attr.env_inherit,
    ))
    providers.append(DefaultInfo(
        files = binary_info.files,
        runfiles = runfiles,
        executable = binary_info.executable,
    ))

    if cc_helper.has_target_constraints(ctx, ctx.attr._apple_constraints):
        # When built for Apple platforms, require the execution to be on a Mac.
        providers.append(testing.ExecutionInfo({"requires-darwin": ""}))
    return providers

def _impl(ctx):
    semantics.validate(ctx, "cc_test")
    cc_test_toolchain = ctx.exec_groups["test"].toolchains[_CC_TEST_TOOLCHAIN_TYPE]
    if cc_test_toolchain:
        cc_test_info = cc_test_toolchain.cc_test_info
    else:
        # This is the "legacy" cc_test flow
        return _legacy_cc_test_impl(ctx)

    binary_info, providers = cc_binary_impl(ctx, cc_test_info.linkopts, cc_test_info.linkstatic)
    processed_environment = cc_helper.get_expanded_env(ctx, {})

    test_providers = cc_test_info.get_runner.func(
        ctx,
        binary_info,
        processed_environment = processed_environment,
        **cc_test_info.get_runner.args
    )
    providers.extend(test_providers)
    return providers

impl = _impl
cc_test_impl_wrapper = wrap_starlark_function(_impl)
