# Copyright 2024 The Bazel Authors. All rights reserved.
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

""" Set of utilities to declare toolchains for `cc_test` targets """

CcTestInfo = provider(
    doc = "Toolchain implementation for @bazel_tools//tools/cpp:test_runner_toolchain_type",
    fields = {
        "get_runner": "(CcTestRunnerInfo) Callback invoked by cc_test, should accept (ctx, binary_info, processed_environment, dynamic_linker) and return a list of providers",
        "linkopts": "(List[String]) Additional linkopts used to link the test binary",
        "linkstatic": "(bool) Whether the test binary should be forced to link statically",
    },
)

CcTestRunnerInfo = provider(
    doc = "Test runner implementation for @bazel_tools//tools/cpp:test_runner_toolchain_type",
    fields = {
        "args": "(dict) dictionary of arguments to pass to the test runner function as kwargs",
        "func": "(fn(ctx, binary_info, processed_environment, **kwargs)) -> List[Provider]) the actual function",
    },
)


_WRAPPER_LABEL_ARG_NAME = "wrapper-label-arg"
_TOOLCHAIN_TARGET_ARG_NAME = "toolchain-target-arg"

def _get_test_runner(ctx, binary_info, processed_environment, **args):
    wrapper = args[_WRAPPER_LABEL_ARG_NAME]
    bin = ctx.actions.declare_file("test_runner_symlink" + args[_TOOLCHAIN_TARGET_ARG_NAME] + "_" + ctx.attr.name)
    ctx.actions.symlink(output=bin, target_file=wrapper[DefaultInfo].files_to_run.executable, is_executable=True)
    runfiles = wrapper.default_runfiles.merge(binary_info.runfiles)

    bin_path = binary_info.executable.short_path

    test_env = { "TEST_BIN": bin_path }
    test_env.update(processed_environment)

    env = RunEnvironmentInfo(environment=test_env)

    return [
        DefaultInfo(
            executable=bin,
            files=depset(transitive=[wrapper.files]),
            runfiles=runfiles,
        ),
        env,
    ]

def _cc_test_toolchain(ctx):
    toolchain_info = platform_common.ToolchainInfo(
        cc_test_info = CcTestInfo(
            linkopts = ctx.attr.linkopts,
            linkstatic = ctx.attr.linkstatic,
            get_runner = CcTestRunnerInfo(
                func = _get_test_runner,
                args = {
                    _WRAPPER_LABEL_ARG_NAME: ctx.attr.wrapper,
                    _TOOLCHAIN_TARGET_ARG_NAME: ctx.attr.name,
                },
            )
        )
    )
    return [
        toolchain_info,
    ]

cc_test_toolchain = rule(
    _cc_test_toolchain,
    attrs = {
        "linkopts": attr.string_list(default = []),
        "linkstatic": attr.bool(default = False),
        "wrapper": attr.label(executable = True, mandatory = True, providers = [DefaultInfo], cfg = "exec"),
    }
)
