# Copyright 2024 The Bazel Authors. All rights reserved.
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
"""Tests for the cc_args rule."""

load("@bazel_skylib//rules/directory:providers.bzl", "DirectoryInfo")
load("//cc:cc_toolchain_config_lib.bzl", "flag_group", "variable_with_value")
load("//cc/toolchains:cc_toolchain_info.bzl", "NestedArgsInfo")
load(
    "//cc/toolchains/impl:nested_args.bzl",
    "FORMAT_ARGS_ERR",
    "REQUIRES_BOOLEAN_MUTUALLY_EXCLUSIVE_ERR",
    "REQUIRES_EQUAL_ERR",
    "REQUIRES_MUTUALLY_EXCLUSIVE_ERR",
    "REQUIRES_NONE_ERR",
    "REQUIRES_NONE_SAME_VARIABLE_ERR",
    "REQUIRES_NOT_NONE_ERR",
    "format_list",
    "nested_args_provider",
)
load("//tests/rule_based_toolchain:generics.bzl", "struct_subject")
load("//tests/rule_based_toolchain:helpers.bzl", "path_pattern")
load("//tests/rule_based_toolchain:subjects.bzl", "result_fn_wrapper", "subjects")

visibility("private")

def _expect_that_nested(env, expr = None, **kwargs):
    return env.expect.that_value(
        expr = expr,
        value = result_fn_wrapper(nested_args_provider)(
            label = Label("//:args"),
            **kwargs
        ),
        factory = subjects.result(subjects.NestedArgsInfo),
    )

def _format_list(args, format, must_use = [], fail = fail):
    formatted, used_items = format_list(args, format, must_use = must_use, fail = fail)
    return struct(
        args = formatted,
        used_items = used_items,
    )

def _expect_that_formatted(env, args, format, must_use = [], expr = None):
    return env.expect.that_value(
        result_fn_wrapper(_format_list)(args, format, must_use = must_use),
        factory = subjects.result(struct_subject(
            args = subjects.collection,
            used_items = subjects.collection,
        )),
        expr = expr or "format_list(%r, %r)" % (args, format),
    )

def _format_args_test(env, targets):
    res = _expect_that_formatted(
        env,
        [
            "a % b",
            "a {{",
            "}} b",
            "a {{ b }}",
        ],
        {},
    ).ok()
    res.args().contains_exactly([
        "a %% b",
        "a {",
        "} b",
        "a { b }",
    ]).in_order()
    res.used_items().contains_exactly([])

    _expect_that_formatted(
        env,
        ["{foo"],
        {},
    ).err().equals('Unmatched { in "{foo"')

    _expect_that_formatted(
        env,
        ["foo}"],
        {},
    ).err().equals('Unexpected } in "foo}"')

    _expect_that_formatted(
        env,
        ["{foo}"],
        {},
    ).err().contains('Unknown variable "foo" in format string "{foo}"')

    res = _expect_that_formatted(
        env,
        [
            "a {var}",
            "b {directory}",
            "c {file}",
        ],
        {
            "directory": targets.directory,
            "file": targets.bin_wrapper,
            "var": targets.foo,
        },
    ).ok()
    res.args().contains_exactly([
        "a %{foo}",
        "b " + path_pattern(targets.directory[DirectoryInfo].path),
        "c " + path_pattern(targets.bin_wrapper[DefaultInfo].files.to_list()[0].path),
    ]).in_order()
    res.used_items().contains_exactly([
        "var",
        "directory",
        "file",
    ])

    res = _expect_that_formatted(
        env,
        ["{var}", "{var}"],
        {"var": targets.foo},
    ).ok()
    res.args().contains_exactly(["%{foo}", "%{foo}"])
    res.used_items().contains_exactly(["var"])

    _expect_that_formatted(
        env,
        [],
        {"var": targets.foo},
        must_use = ["var"],
    ).err().contains('"var" was not used')

    _expect_that_formatted(
        env,
        ["{var} {var}"],
        {"var": targets.foo},
    ).err().contains('"{var} {var}" contained multiple variables')

    _expect_that_formatted(
        env,
        ["{foo} {bar}"],
        {"bar": targets.foo, "foo": targets.foo},
    ).err().contains('"{foo} {bar}" contained multiple variables')

def _iterate_over_test(env, targets):
    inner = _expect_that_nested(
        env,
        args = ["--foo"],
    ).ok().actual
    env.expect.that_str(inner.legacy_flag_group).equals(flag_group(flags = ["--foo"]))

    nested = _expect_that_nested(
        env,
        nested = [inner],
        iterate_over = targets.my_list,
    ).ok()
    nested.iterate_over().some().equals("my_list")
    nested.legacy_flag_group().equals(flag_group(
        iterate_over = "my_list",
        flag_groups = [inner.legacy_flag_group],
    ))
    nested.requires_types().contains_exactly({})

def _requires_types_test(env, targets):
    combined = _expect_that_nested(
        env,
        requires_not_none = "abc",
        requires_none = "def",
        args = ["--foo"],
        expr = "requires_not_none_and_requires_none",
    ).ok()
    combined.legacy_flag_group().equals(flag_group(
        expand_if_available = "abc",
        expand_if_not_available = "def",
        flags = ["--foo"],
    ))
    combined.requires_types().contains_exactly({
        "abc": [struct(
            msg = REQUIRES_NOT_NONE_ERR,
            valid_types = ["option"],
            after_option_unwrap = False,
        )],
        "def": [struct(
            msg = REQUIRES_NONE_ERR,
            valid_types = ["option"],
            after_option_unwrap = False,
        )],
    })

    _expect_that_nested(
        env,
        requires_not_none = "abc",
        requires_none = "abc",
        args = ["--foo"],
        expr = "requires_none_same_variable",
    ).err().equals(REQUIRES_NONE_SAME_VARIABLE_ERR)

    _expect_that_nested(
        env,
        requires_not_none = "abc",
        requires_true = "def",
        args = ["--foo"],
        expr = "mutually_exclusive",
    ).err().equals(REQUIRES_MUTUALLY_EXCLUSIVE_ERR)

    _expect_that_nested(
        env,
        requires_true = "abc",
        requires_false = "def",
        args = ["--foo"],
        expr = "boolean_checks_mutually_exclusive",
    ).err().equals(REQUIRES_BOOLEAN_MUTUALLY_EXCLUSIVE_ERR)

    _expect_that_nested(
        env,
        requires_none = "var",
        args = ["--foo"],
        expr = "requires_none",
    ).ok().requires_types().contains_exactly(
        {"var": [struct(
            msg = REQUIRES_NONE_ERR,
            valid_types = ["option"],
            after_option_unwrap = False,
        )]},
    )

    _expect_that_nested(
        env,
        args = ["foo {foo} baz"],
        format = {targets.foo: "foo"},
        expr = "type_validation",
    ).ok().requires_types().contains_exactly(
        {"foo": [struct(
            msg = FORMAT_ARGS_ERR,
            valid_types = ["string", "file", "directory"],
            after_option_unwrap = True,
        )]},
    )

    nested = _expect_that_nested(
        env,
        requires_equal = "foo",
        requires_equal_value = "value",
        args = ["--foo={foo}"],
        format = {targets.foo: "foo"},
        expr = "type_and_requires_equal_validation",
    ).ok()
    nested.requires_types().contains_exactly(
        {"foo": [
            struct(
                msg = REQUIRES_EQUAL_ERR,
                valid_types = ["string"],
                after_option_unwrap = True,
            ),
            struct(
                msg = FORMAT_ARGS_ERR,
                valid_types = ["string", "file", "directory"],
                after_option_unwrap = True,
            ),
        ]},
    )
    nested.legacy_flag_group().equals(flag_group(
        expand_if_equal = variable_with_value(name = "foo", value = "value"),
        flags = ["--foo=%{foo}"],
    ))

def _nested_make_vars_test(env, targets):
    nested = env.expect.that_target(targets.nested_with_make_vars).provider(NestedArgsInfo)
    nested.legacy_flag_group().equals(flag_group(flags = ["--path=/usr/local", "-DFOO"]))

TARGETS = [
    ":foo",
    ":my_list",
    ":nested_with_make_vars",
    "//tests/rule_based_toolchain/testdata:directory",
    "//tests/rule_based_toolchain/testdata:bin_wrapper",
]

TESTS = {
    "format_args_test": _format_args_test,
    "iterate_over_test": _iterate_over_test,
    "requires_types_test": _requires_types_test,
    "nested_make_vars_test": _nested_make_vars_test,
}
