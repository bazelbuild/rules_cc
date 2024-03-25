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
"""Tests for variables rule."""

load("//cc/toolchains:cc_toolchain_info.bzl", "ActionTypeInfo", "BuiltinVariablesInfo", "VariableInfo")
load("//cc/toolchains/impl:variables.bzl", "types", _get_type = "get_type")
load("//tests/rule_based_toolchain:subjects.bzl", "result_fn_wrapper", "subjects")

visibility("private")

get_type = result_fn_wrapper(_get_type)

_ARGS_LABEL = Label("//:args")
_NESTED_LABEL = Label("//:nested_vars")

def _type(target):
    return target[VariableInfo].type

def _types_represent_correctly_test(env, targets):
    env.expect.that_str(_type(targets.str_list)["repr"]).equals("List[string]")
    env.expect.that_str(_type(targets.str_option)["repr"]).equals("Option[string]")
    env.expect.that_str(_type(targets.struct)["repr"]).equals("struct(nested_str=string, nested_str_list=List[string])")
    env.expect.that_str(_type(targets.struct_list)["repr"]).equals("List[struct(nested_str=string, nested_str_list=List[string])]")

def _get_types_test(env, targets):
    c_compile = targets.c_compile[ActionTypeInfo]
    cpp_compile = targets.cpp_compile[ActionTypeInfo]
    variables = targets.variables[BuiltinVariablesInfo].variables

    def expect_type(key, overrides = {}, expr = None, actions = []):
        return env.expect.that_value(
            get_type(
                variables = variables,
                overrides = overrides,
                args_label = _ARGS_LABEL,
                nested_label = _NESTED_LABEL,
                actions = actions,
                name = key,
            ),
            # It's not a string, it's a complex recursive type, but string
            # supports .equals, which is all we care about.
            factory = subjects.result(subjects.str),
            expr = expr or key,
        )

    expect_type("unknown").err().contains(
        """The variable unknown does not exist. Did you mean one of the following?
str
str_list
""",
    )

    expect_type("str").ok().equals(types.string)
    expect_type("str.invalid").err().equals("""Attempted to access "str.invalid", but "str" was not a struct - it had type string.""")

    expect_type("str_option").ok().equals(types.option(types.string))

    expect_type("str_list").ok().equals(types.list(types.string))

    expect_type("str_list.invalid").err().equals("""Attempted to access "str_list.invalid", but "str_list" was not a struct - it had type List[string].""")

    expect_type("struct").ok().equals(_type(targets.struct))

    expect_type("struct.nested_str_list").ok().equals(types.list(types.string))

    expect_type("struct_list").ok().equals(_type(targets.struct_list))

    expect_type("struct_list.nested_str_list").err().equals("""Attempted to access "struct_list.nested_str_list", but "struct_list" was not a struct - it had type List[struct(nested_str=string, nested_str_list=List[string])]. Maybe you meant to use iterate_over.""")

    expect_type("struct.unknown").err().equals("""Unable to find "unknown" in "struct", which had the following attributes:
nested_str: string
nested_str_list: List[string]""")

    expect_type("struct", actions = [c_compile]).ok()
    expect_type("struct", actions = [c_compile, cpp_compile]).err().equals(
        "The variable %s is inaccessible from the action %s. This is required because it is referenced in %s, which is included by %s, which references that action" % (targets.struct.label, cpp_compile.label, _NESTED_LABEL, _ARGS_LABEL),
    )

    expect_type("struct.nested_str_list", actions = [c_compile]).ok()
    expect_type("struct.nested_str_list", actions = [c_compile, cpp_compile]).err()

    # Simulate someone doing iterate_over = struct_list.
    expect_type(
        "struct_list",
        overrides = {"struct_list": _type(targets.struct)},
        expr = "struct_list_override",
    ).ok().equals(_type(targets.struct))

    expect_type(
        "struct_list.nested_str_list",
        overrides = {"struct_list": _type(targets.struct)},
    ).ok().equals(types.list(types.string))

    expect_type(
        "struct_list.nested_str_list",
        overrides = {
            "struct_list": _type(targets.struct),
            "struct_list.nested_str_list": types.string,
        },
    ).ok().equals(types.string)

TARGETS = [
    "//tests/rule_based_toolchain/actions:c_compile",
    "//tests/rule_based_toolchain/actions:cpp_compile",
    ":str",
    ":str_list",
    ":str_option",
    ":struct",
    ":struct_list",
    ":variables",
]

# @unsorted-dict-items
TESTS = {
    "types_represent_correctly_test": _types_represent_correctly_test,
    "get_types_test": _get_types_test,
}
