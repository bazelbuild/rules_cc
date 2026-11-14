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

"""Regression test for compiler-only flags reaching MASM."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test")

def _compile_action(env, target, source):
    actions = [
        action
        for action in target.actions
        if action.mnemonic == "CppCompile" and
           source in [file.basename for file in action.inputs.to_list()]
    ]
    env.expect.that_collection(actions).has_size(1)
    return actions[0]

def _masm_flags_test_impl(env, target):
    masm_argv = _compile_action(env, target, "masm.asm").argv
    cpp_argv = _compile_action(env, target, "main.cc").argv
    compiler_only_flags = [
        "/bigobj",
        "/Zm500",
        "/EHsc",
        "/wd4351",
        "/wd4291",
        "/wd4250",
        "/wd4996",
    ]
    for flag in compiler_only_flags:
        env.expect.that_collection(masm_argv).not_contains(flag)
    env.expect.that_collection(cpp_argv).contains_at_least(compiler_only_flags)

def masm_flags_test(name, target):
    analysis_test(
        name = name,
        target = target,
        impl = _masm_flags_test_impl,
        attr_values = {
            "target_compatible_with": [
                "@platforms//cpu:x86_64",
                "@platforms//os:windows",
            ],
        },
    )
