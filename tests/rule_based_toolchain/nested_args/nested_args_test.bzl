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

load("//cc:cc_toolchain_config_lib.bzl", "flag_group", "variable_with_value")
load("//cc/toolchains:cc_toolchain_info.bzl", "VariableInfo")
load("//cc/toolchains:format.bzl", "format_arg")
load(
    "//cc/toolchains/impl:nested_args.bzl",
    "FORMAT_ARGS_ERR",
    "REQUIRES_EQUAL_ERR",
    "REQUIRES_MUTUALLY_EXCLUSIVE_ERR",
    "REQUIRES_NONE_ERR",
    "format_string_indexes",
    "format_variable",
    "nested_args_provider",
    "raw_string",
)
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

def _expect_that_formatted(env, var, iterate_over = None, expr = None):
    return env.expect.that_value(
        result_fn_wrapper(format_variable)(var, iterate_over),
        factory = subjects.result(subjects.str),
        expr = expr or "format_variable(var=%r, iterate_over=%r" % (var, iterate_over),
    )

def _expect_that_format_string_indexes(env, var, expr = None):
    return env.expect.that_value(
        result_fn_wrapper(format_string_indexes)(var),
        factory = subjects.result(subjects.collection),
        expr = expr or "format_string_indexes(%r)" % var,
    )

def _format_string_indexes_test(env, _):
    _expect_that_format_string_indexes(env, "foo").ok().contains_exactly([])
    _expect_that_format_string_indexes(env, "%%").ok().contains_exactly([])
    _expect_that_format_string_indexes(env, "%").err().equals(
        '% should always either of the form %s, or escaped with %%. Instead, got "%"',
    )
    _expect_that_format_string_indexes(env, "%a").err().equals(
        '% should always either of the form %s, or escaped with %%. Instead, got "%a"',
    )
    _expect_that_format_string_indexes(env, "%s").ok().contains_exactly([0])
    _expect_that_format_string_indexes(env, "%%%s%s").ok().contains_exactly([2, 4])
    _expect_that_format_string_indexes(env, "%%{").ok().contains_exactly([])
    _expect_that_format_string_indexes(env, "%%s").ok().contains_exactly([])
    _expect_that_format_string_indexes(env, "%{foo}").err().equals(
        'Using the old mechanism for variables, %{variable}, but we instead use format_arg("--foo=%s", "//cc/toolchains/variables:<variable>"). Got "%{foo}"',
    )

def _formats_raw_strings_test(env, _):
    _expect_that_formatted(
        env,
        raw_string("foo"),
    ).ok().equals("foo")
    _expect_that_formatted(
        env,
        raw_string("%s"),
    ).err().contains("Can't use %s with a raw string. Either escape it with %%s or use format_arg")

def _formats_variables_test(env, targets):
    _expect_that_formatted(
        env,
        format_arg("ab %s cd", targets.foo[VariableInfo]),
    ).ok().equals("ab %{foo} cd")

    _expect_that_formatted(
        env,
        format_arg("foo", targets.foo[VariableInfo]),
    ).err().equals('format_arg requires a "%s" in the format string, but got "foo"')
    _expect_that_formatted(
        env,
        format_arg("%s%s", targets.foo[VariableInfo]),
    ).err().equals('Only one %s can be used in a format string, but got "%s%s"')

    _expect_that_formatted(
        env,
        format_arg("%s"),
        iterate_over = "foo",
    ).ok().equals("%{foo}")
    _expect_that_formatted(
        env,
        format_arg("%s"),
    ).err().contains("format_arg requires either a variable to format, or iterate_over must be provided")

def _iterate_over_test(env, _):
    inner = _expect_that_nested(
        env,
        args = [raw_string("--foo")],
    ).ok().actual
    env.expect.that_str(inner.legacy_flag_group).equals(flag_group(flags = ["--foo"]))

    nested = _expect_that_nested(
        env,
        nested = [inner],
        iterate_over = "my_list",
    ).ok()
    nested.iterate_over().some().equals("my_list")
    nested.legacy_flag_group().equals(flag_group(
        iterate_over = "my_list",
        flag_groups = [inner.legacy_flag_group],
    ))
    nested.requires_types().contains_exactly({})

def _requires_types_test(env, targets):
    _expect_that_nested(
        env,
        requires_not_none = "abc",
        requires_none = "def",
        args = [raw_string("--foo")],
        expr = "mutually_exclusive",
    ).err().equals(REQUIRES_MUTUALLY_EXCLUSIVE_ERR)

    _expect_that_nested(
        env,
        requires_none = "var",
        args = [raw_string("--foo")],
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
        args = [raw_string("foo %s baz")],
        expr = "no_variable",
    ).err().contains("Can't use %s with a raw string")

    _expect_that_nested(
        env,
        args = [format_arg("foo %s baz", targets.foo[VariableInfo])],
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
        args = [format_arg("--foo=%s", targets.foo[VariableInfo])],
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

TARGETS = [
    ":foo",
]

TESTS = {
    "format_string_indexes_test": _format_string_indexes_test,
    "formats_raw_strings_test": _formats_raw_strings_test,
    "formats_variables_test": _formats_variables_test,
    "iterate_over_test": _iterate_over_test,
    "requires_types_test": _requires_types_test,
}
