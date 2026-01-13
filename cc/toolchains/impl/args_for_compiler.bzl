# Copyright 2026 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Macros for applying compiler constraints to cc_args."""

load("//cc/toolchains:args.bzl", "cc_args")
load("//cc/toolchains:feature_constraint.bzl", "cc_feature_constraint")

visibility([
    "//cc/toolchains/...",
    "//tests/rule_based_toolchain/...",
])

_ALL_COMPILERS = [
    "clang",
    "clang-cl",
    "gcc",
    "mingw-gcc",
    "msvc-cl",
    "emscripten",
]

def _compiler_label(name):
    return "//cc/toolchains/compiler:{}".format(name)

def _normalize_compilers(compilers, exclude_compilers, fail):
    if compilers and exclude_compilers:
        fail("Only one of 'compilers' or 'exclude_compilers' may be set.")

    if compilers:
        for name in compilers:
            if name not in _ALL_COMPILERS:
                fail("Unknown compiler name {} in compilers.".format(name))
        return [_compiler_label(name) for name in compilers]

    if exclude_compilers:
        exclude = {name: True for name in exclude_compilers}
        for name in exclude:
            if name not in _ALL_COMPILERS:
                fail("Unknown compiler name {} in exclude_compilers.".format(name))
        return [_compiler_label(name) for name in _ALL_COMPILERS if name not in exclude]

    return []

def _merge_requires_any_of(name, base_requires_any_of, compiler_constraints):
    if not compiler_constraints:
        return list(base_requires_any_of or [])

    if not base_requires_any_of:
        return list(compiler_constraints)

    merged = []
    for base_idx, base in enumerate(base_requires_any_of):
        for compiler_idx, compiler in enumerate(compiler_constraints):
            constraint_name = "{}_compiler_constraint_{}_{}".format(
                name,
                base_idx,
                compiler_idx,
            )
            cc_feature_constraint(
                name = constraint_name,
                all_of = [base, compiler],
            )
            merged.append(":{}".format(constraint_name))

    return merged

def cc_args_for_compiler(
        *,
        name,
        compilers = None,
        exclude_compilers = None,
        requires_any_of = None,
        args_rule = cc_args,
        **kwargs):
    """cc_args wrapper that limits args to specific compiler(s).

    Use either `compiler` or `exclude_compiler`
    """
    compiler_constraints = _normalize_compilers(
        compilers,
        exclude_compilers,
        fail,
    )
    merged_requires = _merge_requires_any_of(
        name,
        requires_any_of or [],
        compiler_constraints,
    )
    args_rule(
        name = name,
        requires_any_of = merged_requires,
        **kwargs
    )
