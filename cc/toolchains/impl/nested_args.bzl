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
"""Helper functions for working with args."""

load("@bazel_skylib//lib:structs.bzl", "structs")
load("//cc:cc_toolchain_config_lib.bzl", "flag_group", "variable_with_value")
load("//cc/toolchains:cc_toolchain_info.bzl", "NestedArgsInfo", "VariableInfo")
load(":collect.bzl", "collect_files", "collect_provider")

visibility([
    "//cc/toolchains",
    "//tests/rule_based_toolchain/...",
])

REQUIRES_MUTUALLY_EXCLUSIVE_ERR = "requires_none, requires_not_none, requires_true, requires_false, and requires_equal are mutually exclusive"
REQUIRES_NOT_NONE_ERR = "requires_not_none only works on options"
REQUIRES_NONE_ERR = "requires_none only works on options"
REQUIRES_TRUE_ERR = "requires_true only works on bools"
REQUIRES_FALSE_ERR = "requires_false only works on bools"
REQUIRES_EQUAL_ERR = "requires_equal only works on strings"
REQUIRES_EQUAL_VALUE_ERR = "When requires_equal is provided, you must also provide requires_equal_value to specify what it should be equal to"
FORMAT_ARGS_ERR = "format_args can only format strings, files, or directories"

_NOT_ESCAPED_FMT = "%% should always either of the form %%s, or escaped with %%%%. Instead, got %r"

_EXAMPLE = """

cc_args(
    ...,
    args = [format_arg("--foo=%s", "//cc/toolchains/variables:foo")]
)

or

cc_args(
    ...,
    # If foo_list contains ["a", "b"], then this expands to ["--foo", "+a", "--foo", "+b"].
    args = ["--foo", format_arg("+%s")],
    iterate_over = "//toolchains/variables:foo_list",
"""

# @unsorted-dict-items.
NESTED_ARGS_ATTRS = {
    "args": attr.string_list(
        doc = """json-encoded arguments to be added to the command-line.

Usage:
cc_args(
    ...,
    args = ["--foo", format_arg("%s", "//cc/toolchains/variables:foo")]
)

This is equivalent to flag_group(flags = ["--foo", "%{foo}"])

Mutually exclusive with nested.
""",
    ),
    "nested": attr.label_list(
        providers = [NestedArgsInfo],
        doc = """nested_args that should be added on the command-line.

Mutually exclusive with args.""",
    ),
    "data": attr.label_list(
        allow_files = True,
        doc = """Files required to add this argument to the command-line.

For example, a flag that sets the header directory might add the headers in that
directory as additional files.
""",
    ),
    "variables": attr.label_list(
        providers = [VariableInfo],
        doc = "Variables to be used in substitutions",
    ),
    "iterate_over": attr.label(providers = [VariableInfo], doc = "Replacement for flag_group.iterate_over"),
    "requires_not_none": attr.label(providers = [VariableInfo], doc = "Replacement for flag_group.expand_if_available"),
    "requires_none": attr.label(providers = [VariableInfo], doc = "Replacement for flag_group.expand_if_not_available"),
    "requires_true": attr.label(providers = [VariableInfo], doc = "Replacement for flag_group.expand_if_true"),
    "requires_false": attr.label(providers = [VariableInfo], doc = "Replacement for flag_group.expand_if_false"),
    "requires_equal": attr.label(providers = [VariableInfo], doc = "Replacement for flag_group.expand_if_equal"),
    "requires_equal_value": attr.string(),
}

def args_wrapper_macro(*, name, rule, args = [], **kwargs):
    """Invokes a rule by converting args to attributes.

    Args:
        name: (str) The name of the target.
        rule: (rule) The rule to invoke. Either cc_args or cc_nested_args.
        args: (List[str|Formatted]) A list of either strings, or function calls
          from format.bzl. For example:
            ["--foo", format_arg("--sysroot=%s", "//cc/toolchains/variables:sysroot")]
        **kwargs: kwargs to pass through into the rule invocation.
    """
    out_args = []
    vars = []
    if type(args) != "list":
        fail("Args must be a list in %s" % native.package_relative_label(name))
    for arg in args:
        if type(arg) == "string":
            out_args.append(raw_string(arg))
        elif getattr(arg, "format_type") == "format_arg":
            arg = structs.to_dict(arg)
            if arg["value"] == None:
                out_args.append(arg)
            else:
                var = arg.pop("value")

                # Swap the variable from a label to an index. This allows us to
                # actually get the providers in a rule.
                out_args.append(struct(value = len(vars), **arg))
                vars.append(var)
        else:
            fail("Invalid type of args in %s. Expected either a string or format_args(format_string, variable_label), got value %r" % (native.package_relative_label(name), arg))

    rule(
        name = name,
        args = [json.encode(arg) for arg in out_args],
        variables = vars,
        **kwargs
    )

def _var(target):
    if target == None:
        return None
    return target[VariableInfo].name

# TODO: Consider replacing this with a subrule in the future. However, maybe not
# for a long time, since it'll break compatibility with all bazel versions < 7.
def nested_args_provider_from_ctx(ctx):
    """Gets the nested args provider from a rule that has NESTED_ARGS_ATTRS.

    Args:
        ctx: The rule context
    Returns:
        NestedArgsInfo
    """
    variables = collect_provider(ctx.attr.variables, VariableInfo)
    args = []
    for arg in ctx.attr.args:
        arg = json.decode(arg)
        if "value" in arg:
            if arg["value"] != None:
                arg["value"] = variables[arg["value"]]
        args.append(struct(**arg))

    return nested_args_provider(
        label = ctx.label,
        args = args,
        nested = collect_provider(ctx.attr.nested, NestedArgsInfo),
        files = collect_files(ctx.attr.data),
        iterate_over = _var(ctx.attr.iterate_over),
        requires_not_none = _var(ctx.attr.requires_not_none),
        requires_none = _var(ctx.attr.requires_none),
        requires_true = _var(ctx.attr.requires_true),
        requires_false = _var(ctx.attr.requires_false),
        requires_equal = _var(ctx.attr.requires_equal),
        requires_equal_value = ctx.attr.requires_equal_value,
    )

def raw_string(s):
    """Constructs metadata for creating a raw string.

    Args:
      s: (str) The string to input.
    Returns:
      Metadata suitable for format_variable.
    """
    return struct(format_type = "raw", format = s)

def format_string_indexes(s, fail = fail):
    """Gets the index of a '%s' in a string.

    Args:
      s: (str) The string
      fail: The fail function. Used for tests

    Returns:
      List[int] The indexes of the '%s' in the string
    """
    indexes = []
    escaped = False
    for i in range(len(s)):
        if not escaped and s[i] == "%":
            escaped = True
        elif escaped:
            if s[i] == "{":
                fail('Using the old mechanism for variables, %%{variable}, but we instead use format_arg("--foo=%%s", "//cc/toolchains/variables:<variable>"). Got %r' % s)
            elif s[i] == "s":
                indexes.append(i - 1)
            elif s[i] != "%":
                fail(_NOT_ESCAPED_FMT % s)
            escaped = False
    if escaped:
        return fail(_NOT_ESCAPED_FMT % s)
    return indexes

def format_variable(arg, iterate_over, fail = fail):
    """Lists all of the variables referenced by an argument.

    Eg: referenced_variables([
        format_arg("--foo", None),
        format_arg("--bar=%s", ":bar")
    ]) => ["--foo", "--bar=%{bar}"]

    Args:
      arg: [Formatted] The command-line arguments, as created by the format_arg function.
      iterate_over: (Optional[str]) The name of the variable we're iterating over.
      fail: The fail function. Used for tests

    Returns:
      A string defined to be compatible with flag groups.
    """
    indexes = format_string_indexes(arg.format, fail = fail)
    if arg.format_type == "raw":
        if indexes:
            return fail("Can't use %s with a raw string. Either escape it with %%s or use format_arg, like the following examples:" + _EXAMPLE)
        return arg.format
    else:
        if len(indexes) == 0:
            return fail('format_arg requires a "%%s" in the format string, but got %r' % arg.format)
        elif len(indexes) > 1:
            return fail("Only one %%s can be used in a format string, but got %r" % arg.format)

        if arg.value == None:
            if iterate_over == None:
                return fail("format_arg requires either a variable to format, or iterate_over must be provided. For example:" + _EXAMPLE)
            var = iterate_over
        else:
            var = arg.value.name

        index = indexes[0]
        return arg.format[:index] + "%{" + var + "}" + arg.format[index + 2:]

def nested_args_provider(
        *,
        label,
        args = [],
        nested = [],
        files = depset([]),
        iterate_over = None,
        requires_not_none = None,
        requires_none = None,
        requires_true = None,
        requires_false = None,
        requires_equal = None,
        requires_equal_value = "",
        fail = fail):
    """Creates a validated NestedArgsInfo.

    Does not validate types, as you can't know the type of a variable until
    you have a cc_args wrapping it, because the outer layers can change that
    type using iterate_over.

    Args:
        label: (Label) The context we are currently evaluating in. Used for
          error messages.
        args: (List[str]) The command-line arguments to add.
        nested: (List[NestedArgsInfo]) command-line arguments to expand.
        files: (depset[File]) Files required for this set of command-line args.
        iterate_over: (Optional[str]) Variable to iterate over
        requires_not_none: (Optional[str]) If provided, this NestedArgsInfo will
          be ignored if the variable is None
        requires_none: (Optional[str]) If provided, this NestedArgsInfo will
          be ignored if the variable is not None
        requires_true: (Optional[str]) If provided, this NestedArgsInfo will
          be ignored if the variable is false
        requires_false: (Optional[str]) If provided, this NestedArgsInfo will
          be ignored if the variable is true
        requires_equal: (Optional[str]) If provided, this NestedArgsInfo will
          be ignored if the variable is not equal to requires_equal_value.
        requires_equal_value: (str) The value to compare the requires_equal
          variable with
        fail: A fail function. Use only for testing.
    Returns:
        NestedArgsInfo
    """
    if bool(args) == bool(nested):
        fail("Exactly one of args and nested must be provided")

    transitive_files = [ea.files for ea in nested]
    transitive_files.append(files)

    has_value = [attr for attr in [
        requires_not_none,
        requires_none,
        requires_true,
        requires_false,
        requires_equal,
    ] if attr != None]

    # We may want to reconsider this down the line, but it's easier to open up
    # an API than to lock down an API.
    if len(has_value) > 1:
        fail(REQUIRES_MUTUALLY_EXCLUSIVE_ERR)

    kwargs = {}
    requires_types = {}
    if nested:
        kwargs["flag_groups"] = [ea.legacy_flag_group for ea in nested]

    unwrap_options = []

    if iterate_over:
        kwargs["iterate_over"] = iterate_over

    if requires_not_none:
        kwargs["expand_if_available"] = requires_not_none
        requires_types.setdefault(requires_not_none, []).append(struct(
            msg = REQUIRES_NOT_NONE_ERR,
            valid_types = ["option"],
            after_option_unwrap = False,
        ))
        unwrap_options.append(requires_not_none)
    elif requires_none:
        kwargs["expand_if_not_available"] = requires_none
        requires_types.setdefault(requires_none, []).append(struct(
            msg = REQUIRES_NONE_ERR,
            valid_types = ["option"],
            after_option_unwrap = False,
        ))
    elif requires_true:
        kwargs["expand_if_true"] = requires_true
        requires_types.setdefault(requires_true, []).append(struct(
            msg = REQUIRES_TRUE_ERR,
            valid_types = ["bool"],
            after_option_unwrap = True,
        ))
        unwrap_options.append(requires_true)
    elif requires_false:
        kwargs["expand_if_false"] = requires_false
        requires_types.setdefault(requires_false, []).append(struct(
            msg = REQUIRES_FALSE_ERR,
            valid_types = ["bool"],
            after_option_unwrap = True,
        ))
        unwrap_options.append(requires_false)
    elif requires_equal:
        if not requires_equal_value:
            fail(REQUIRES_EQUAL_VALUE_ERR)
        kwargs["expand_if_equal"] = variable_with_value(
            name = requires_equal,
            value = requires_equal_value,
        )
        unwrap_options.append(requires_equal)
        requires_types.setdefault(requires_equal, []).append(struct(
            msg = REQUIRES_EQUAL_ERR,
            valid_types = ["string"],
            after_option_unwrap = True,
        ))

    for arg in args:
        if arg.format_type != "raw":
            var_name = arg.value.name if arg.value != None else iterate_over
            requires_types.setdefault(var_name, []).append(struct(
                msg = FORMAT_ARGS_ERR,
                valid_types = ["string", "file", "directory"],
                after_option_unwrap = True,
            ))

    if args:
        kwargs["flags"] = [
            format_variable(arg, iterate_over = iterate_over, fail = fail)
            for arg in args
        ]

    return NestedArgsInfo(
        label = label,
        nested = nested,
        files = depset(transitive = transitive_files),
        iterate_over = iterate_over,
        unwrap_options = unwrap_options,
        requires_types = requires_types,
        legacy_flag_group = flag_group(**kwargs),
    )
