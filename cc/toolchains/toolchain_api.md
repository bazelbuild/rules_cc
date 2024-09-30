<!-- Generated with Stardoc: http://skydoc.bazel.build -->

This is a list of rules/macros that should be exported as documentation.

<a id="cc_action_type"></a>

## cc_action_type

<pre>
cc_action_type(<a href="#cc_action_type-name">name</a>, <a href="#cc_action_type-action_name">action_name</a>)
</pre>

A type of action (eg. c_compile, assemble, strip).

[`cc_action_type`](#cc_action_type) rules are used to associate arguments and tools together to
perform a specific action. Bazel prescribes a set of known action types that are used to drive
typical C/C++/ObjC actions like compiling, linking, and archiving. The set of well-known action
types can be found in [@rules_cc//cc/toolchains/actions:BUILD](https://github.com/bazelbuild/rules_cc/tree/main/cc/toolchains/actions/BUILD).

It's possible to create project-specific action types for use in toolchains. Be careful when
doing this, because every toolchain that encounters the action will need to be configured to
support the custom action type. If your project is a library, avoid creating new action types as
it will reduce compatibility with existing toolchains and increase setup complexity for users.

Example:
```
load("@rules_cc//cc:action_names.bzl", "ACTION_NAMES")
load("@rules_cc//cc/toolchains:actions.bzl", "cc_action_type")

cc_action_type(
    name = "cpp_compile",
    action_name =  = ACTION_NAMES.cpp_compile,
)
```

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="cc_action_type-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="cc_action_type-action_name"></a>action_name |  -   | String | required |  |


<a id="cc_action_type_set"></a>

## cc_action_type_set

<pre>
cc_action_type_set(<a href="#cc_action_type_set-name">name</a>, <a href="#cc_action_type_set-actions">actions</a>, <a href="#cc_action_type_set-allow_empty">allow_empty</a>)
</pre>

Represents a set of actions.

This is a convenience rule to allow for more compact representation of a group of action types.
Use this anywhere a [`cc_action_type`](#cc_action_type) is accepted.

Example:
```
load("@rules_cc//cc/toolchains:actions.bzl", "cc_action_type_set")

cc_action_type_set(
    name = "link_executable_actions",
    actions = [
        "@rules_cc//cc/toolchains/actions:cpp_link_executable",
        "@rules_cc//cc/toolchains/actions:lto_index_for_executable",
    ],
)
```

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="cc_action_type_set-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="cc_action_type_set-actions"></a>actions |  A list of cc_action_type or cc_action_type_set   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="cc_action_type_set-allow_empty"></a>allow_empty |  -   | Boolean | optional |  `False`  |


<a id="cc_args_list"></a>

## cc_args_list

<pre>
cc_args_list(<a href="#cc_args_list-name">name</a>, <a href="#cc_args_list-args">args</a>)
</pre>

An ordered list of cc_args.

This is a convenience rule to allow you to group a set of multiple [`cc_args`](#cc_args) into a
single list. This particularly useful for toolchain behaviors that require different flags for
different actions.

Note: The order of the arguments in `args` is preserved to support order-sensitive flags.

Example usage:
```
load("@rules_cc//cc/toolchains:cc_args.bzl", "cc_args")
load("@rules_cc//cc/toolchains:args_list.bzl", "cc_args_list")

cc_args(
    name = "gc_sections",
    actions = [
        "@rules_cc//cc/toolchains/actions:link_actions",
    ],
    args = ["-Wl,--gc-sections"],
)

cc_args(
    name = "function_sections",
    actions = [
        "@rules_cc//cc/toolchains/actions:compile_actions",
        "@rules_cc//cc/toolchains/actions:link_actions",
    ],
    args = ["-ffunction-sections"],
)

cc_args_list(
    name = "gc_functions",
    args = [
        ":function_sections",
        ":gc_sections",
    ],
)
```

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="cc_args_list-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="cc_args_list-args"></a>args |  (ordered) cc_args to include in this list.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |


<a id="cc_tool"></a>

## cc_tool

<pre>
cc_tool(<a href="#cc_tool-name">name</a>, <a href="#cc_tool-src">src</a>, <a href="#cc_tool-data">data</a>, <a href="#cc_tool-allowlist_include_directories">allowlist_include_directories</a>)
</pre>

Declares a tool for use by toolchain actions.

[`cc_tool`](#cc_tool) rules are used in a [`cc_tool_map`](#cc_tool_map) rule to ensure all files and
metadata required to run a tool are available when constructing a `cc_toolchain`.

In general, include all files that are always required to run a tool (e.g. libexec/** and
cross-referenced tools in bin/*) in the [data](#cc_tool-data) attribute. If some files are only
required when certain flags are passed to the tool, consider using a [`cc_args`](#cc_args) rule to
bind the files to the flags that require them. This reduces the overhead required to properly
enumerate a sandbox with all the files required to run a tool, and ensures that there isn't
unintentional leakage across configurations and actions.

Example:
```
load("@rules_cc//cc/toolchains:tool.bzl", "cc_tool")

cc_tool(
    name = "clang_tool",
    executable = "@llvm_toolchain//:bin/clang",
    # Suppose clang needs libc to run.
    data = ["@llvm_toolchain//:lib/x86_64-linux-gnu/libc.so.6"]
    tags = ["requires-network"],
)
```

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="cc_tool-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="cc_tool-src"></a>src |  The underlying binary that this tool represents.<br><br>Usually just a single prebuilt (eg. @toolchain//:bin/clang), but may be any executable label.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="cc_tool-data"></a>data |  Additional files that are required for this tool to run.<br><br>Frequently, clang and gcc require additional files to execute as they often shell out to other binaries (e.g. `cc1`).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="cc_tool-allowlist_include_directories"></a>allowlist_include_directories |  Include paths implied by using this tool.<br><br>Compilers may include a set of built-in headers that are implicitly available unless flags like `-nostdinc` are provided. Bazel checks that all included headers are properly provided by a dependency or allowlisted through this mechanism.<br><br>As a rule of thumb, only use this if Bazel is complaining about absolute paths in your toolchain and you've ensured that the toolchain is compiling with the `-no-canonical-prefixes` and/or `-fno-canonical-system-headers` arguments.<br><br>This can help work around errors like: `the source file 'main.c' includes the following non-builtin files with absolute paths (if these are builtin files, make sure these paths are in your toolchain)`.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |


<a id="cc_args"></a>

## cc_args

<pre>
cc_args(<a href="#cc_args-name">name</a>, <a href="#cc_args-actions">actions</a>, <a href="#cc_args-allowlist_include_directories">allowlist_include_directories</a>, <a href="#cc_args-args">args</a>, <a href="#cc_args-data">data</a>, <a href="#cc_args-env">env</a>, <a href="#cc_args-format">format</a>, <a href="#cc_args-iterate_over">iterate_over</a>, <a href="#cc_args-nested">nested</a>,
        <a href="#cc_args-requires_not_none">requires_not_none</a>, <a href="#cc_args-requires_none">requires_none</a>, <a href="#cc_args-requires_true">requires_true</a>, <a href="#cc_args-requires_false">requires_false</a>, <a href="#cc_args-requires_equal">requires_equal</a>,
        <a href="#cc_args-requires_equal_value">requires_equal_value</a>, <a href="#cc_args-requires_any_of">requires_any_of</a>, <a href="#cc_args-kwargs">kwargs</a>)
</pre>

Action-specific arguments for use with a cc_toolchain.

This rule is the fundamental building building block for every toolchain tool invocation. Each
argument expressed in a toolchain tool invocation (e.g. `gcc`, `llvm-ar`) is declared in a
[`cc_args`](#cc_args) rule that applies an ordered list of arguments to a set of toolchain
actions. [`cc_args`](#cc_args) rules can be added unconditionally to a
`cc_toolchain`, conditionally via `select()` statements, or dynamically via an
intermediate `cc_feature`.

Conceptually, this is similar to the old `CFLAGS`, `CPPFLAGS`, etc. environment variables that
many build systems use to determine which flags to use for a given action. The significant
difference is that [`cc_args`](#cc_args) rules are declared in a structured way that allows for
significantly more powerful and sharable toolchain configurations. Also, due to Bazel's more
granular action types, it's possible to bind flags to very specific actions (e.g. LTO indexing
for an executable vs a dynamic library) multiple different actions (e.g. C++ compile and link
simultaneously).

Example usage:
```
load("@rules_cc//cc/toolchains:args.bzl", "cc_args")

# Basic usage: a trivial flag.
#
# An example of expressing `-Werror` as a [`cc_args`](#cc_args) rule.
cc_args(
    name = "warnings_as_errors",
    actions = [
        # Applies to all C/C++ compile actions.
        "@rules_cc//cc/toolchains/actions:compile_actions",
    ],
    args = ["-Werror"],
)

# Basic usage: ordered flags.
#
# An example of linking against libc++, which uses two flags that must be applied in order.
cc_args(
    name = "link_libcxx",
    actions = [
        # Applies to all link actions.
        "@rules_cc//cc/toolchains/actions:link_actions",
    ],
    # On tool invocation, this appears as `-Xlinker -lc++`. Nothing will ever end up between
    # the two flags.
    args = [
        "-Xlinker",
        "-lc++",
    ],
)

# Advanced usage: built-in variable expansions.
#
# Expands to `-L/path/to/search_dir` for each directory in the built-in variable
# `library_search_directories`. This variable is managed internally by Bazel through inherent
# behaviors of Bazel and the interactions between various C/C++ build rules.
cc_args(
    name = "library_search_directories",
    actions = [
        "@rules_cc//cc/toolchains/actions:link_actions",
    ],
    args = ["-L{search_dir}"],
    iterate_over = "@rules_cc//cc/toolchains/variables:library_search_directories",
    requires_not_none = "@rules_cc//cc/toolchains/variables:library_search_directories",
    format = {
        "search_dir": "@rules_cc//cc/toolchains/variables:library_search_directories",
    },
)
```

For more extensive examples, see the usages here:
    https://github.com/bazelbuild/rules_cc/tree/main/cc/toolchains/args


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="cc_args-name"></a>name |  (str) The name of the target.   |  none |
| <a id="cc_args-actions"></a>actions |  (List[Label]) A list of labels of [`cc_action_type`](#cc_action_type) or [`cc_action_type_set`](#cc_action_type_set) rules that dictate which actions these arguments should be applied to.   |  `None` |
| <a id="cc_args-allowlist_include_directories"></a>allowlist_include_directories |  (List[Label]) A list of include paths that are implied by using this rule. These must point to a skylib [directory](https://github.com/bazelbuild/bazel-skylib/tree/main/doc/directory_doc.md#directory) or [subdirectory](https://github.com/bazelbuild/bazel-skylib/tree/main/doc/directory_subdirectory_doc.md#subdirectory) rule. Some flags (e.g. --sysroot) imply certain include paths are available despite not explicitly specifying a normal include path flag (`-I`, `-isystem`, etc.). Bazel checks that all included headers are properly provided by a dependency or allowlisted through this mechanism.<br><br>As a rule of thumb, only use this if Bazel is complaining about absolute paths in your toolchain and you've ensured that the toolchain is compiling with the `-no-canonical-prefixes` and/or `-fno-canonical-system-headers` arguments.<br><br>This can help work around errors like: `the source file 'main.c' includes the following non-builtin files with absolute paths (if these are builtin files, make sure these paths are in your toolchain)`.   |  `None` |
| <a id="cc_args-args"></a>args |  (List[str]) The command-line arguments that are applied by using this rule. This is mutually exclusive with [nested](#cc_args-nested).   |  `None` |
| <a id="cc_args-data"></a>data |  (List[Label]) A list of runtime data dependencies that are required for these arguments to work as intended.   |  `None` |
| <a id="cc_args-env"></a>env |  (Dict[str, str]) Environment variables that should be set when the tool is invoked.   |  `None` |
| <a id="cc_args-format"></a>format |  (Dict[str, Label]) A mapping of format strings to the label of the corresponding [`cc_variable`](#cc_variable) that the value should be pulled from. All instances of `{variable_name}` will be replaced with the expanded value of `variable_name` in this dictionary. The complete list of possible variables can be found in https://github.com/bazelbuild/rules_cc/tree/main/cc/toolchains/variables/BUILD. It is not possible to declare custom variables--these are inherent to Bazel itself.   |  `{}` |
| <a id="cc_args-iterate_over"></a>iterate_over |  (Label) The label of a [`cc_variable`](#cc_variable) that should be iterated over. This is intended for use with built-in variables that are lists.   |  `None` |
| <a id="cc_args-nested"></a>nested |  (List[Label]) A list of [`cc_nested_args`](#cc_nested_args) rules that should be expanded to command-line arguments when this rule is used. This is mutually exclusive with [args](#cc_args-args).   |  `None` |
| <a id="cc_args-requires_not_none"></a>requires_not_none |  (Label) The label of a [`cc_variable`](#cc_variable) that should be checked for existence before expanding this rule. If the variable is None, this rule will be ignored.   |  `None` |
| <a id="cc_args-requires_none"></a>requires_none |  (Label) The label of a [`cc_variable`](#cc_variable) that should be checked for non-existence before expanding this rule. If the variable is not None, this rule will be ignored.   |  `None` |
| <a id="cc_args-requires_true"></a>requires_true |  (Label) The label of a [`cc_variable`](#cc_variable) that should be checked for truthiness before expanding this rule. If the variable is false, this rule will be ignored.   |  `None` |
| <a id="cc_args-requires_false"></a>requires_false |  (Label) The label of a [`cc_variable`](#cc_variable) that should be checked for falsiness before expanding this rule. If the variable is true, this rule will be ignored.   |  `None` |
| <a id="cc_args-requires_equal"></a>requires_equal |  (Label) The label of a [`cc_variable`](#cc_variable) that should be checked for equality before expanding this rule. If the variable is not equal to (requires_equal_value)[#cc_args-requires_equal_value], this rule will be ignored.   |  `None` |
| <a id="cc_args-requires_equal_value"></a>requires_equal_value |  (str) The value to compare (requires_equal)[#cc_args-requires_equal] against.   |  `None` |
| <a id="cc_args-requires_any_of"></a>requires_any_of |  (List[Label]) These arguments will be used in a tool invocation when at least one of the [cc_feature_constraint](#cc_feature_constraint) entries in this list are satisfied. If omitted, this flag set will be enabled unconditionally.   |  `None` |
| <a id="cc_args-kwargs"></a>kwargs |  [common attributes](https://bazel.build/reference/be/common-definitions#common-attributes) that should be applied to this rule.   |  none |


<a id="cc_nested_args"></a>

## cc_nested_args

<pre>
cc_nested_args(<a href="#cc_nested_args-name">name</a>, <a href="#cc_nested_args-args">args</a>, <a href="#cc_nested_args-data">data</a>, <a href="#cc_nested_args-format">format</a>, <a href="#cc_nested_args-iterate_over">iterate_over</a>, <a href="#cc_nested_args-nested">nested</a>, <a href="#cc_nested_args-requires_not_none">requires_not_none</a>, <a href="#cc_nested_args-requires_none">requires_none</a>,
               <a href="#cc_nested_args-requires_true">requires_true</a>, <a href="#cc_nested_args-requires_false">requires_false</a>, <a href="#cc_nested_args-requires_equal">requires_equal</a>, <a href="#cc_nested_args-requires_equal_value">requires_equal_value</a>, <a href="#cc_nested_args-kwargs">kwargs</a>)
</pre>

Nested arguments for use in more complex [`cc_args`](#cc_args) expansions.

While this rule is very similar in shape to [`cc_args`](#cc_args), it is intended to be used as a
dependency of [`cc_args`](#cc_args) to provide additional arguments that should be applied to the
same actions as defined by the parent [`cc_args`](#cc_args) rule. The key motivation for this rule
is to allow for more complex variable-based argument expensions.

Prefer expressing collections of arguments as [`cc_args`](#cc_args) and
[`cc_args_list`](#cc_args_list) rules when possible.

For living examples of how this rule is used, see the usages here:
    https://github.com/bazelbuild/rules_cc/tree/main/cc/toolchains/args/runtime_library_search_directories/BUILD
    https://github.com/bazelbuild/rules_cc/tree/main/cc/toolchains/args/libraries_to_link/BUILD

Note: These examples are non-trivial, but they illustrate when it is absolutely necessary to
use this rule.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="cc_nested_args-name"></a>name |  (str) The name of the target.   |  none |
| <a id="cc_nested_args-args"></a>args |  (List[str]) The command-line arguments that are applied by using this rule. This is mutually exclusive with [nested](#cc_nested_args-nested).   |  `None` |
| <a id="cc_nested_args-data"></a>data |  (List[Label]) A list of runtime data dependencies that are required for these arguments to work as intended.   |  `None` |
| <a id="cc_nested_args-format"></a>format |  (Dict[str, Label]) A mapping of format strings to the label of the corresponding [`cc_variable`](#cc_variable) that the value should be pulled from. All instances of `{variable_name}` will be replaced with the expanded value of `variable_name` in this dictionary. The complete list of possible variables can be found in https://github.com/bazelbuild/rules_cc/tree/main/cc/toolchains/variables/BUILD. It is not possible to declare custom variables--these are inherent to Bazel itself.   |  `{}` |
| <a id="cc_nested_args-iterate_over"></a>iterate_over |  (Label) The label of a [`cc_variable`](#cc_variable) that should be iterated over. This is intended for use with built-in variables that are lists.   |  `None` |
| <a id="cc_nested_args-nested"></a>nested |  (List[Label]) A list of [`cc_nested_args`](#cc_nested_args) rules that should be expanded to command-line arguments when this rule is used. This is mutually exclusive with [args](#cc_nested_args-args).   |  `None` |
| <a id="cc_nested_args-requires_not_none"></a>requires_not_none |  (Label) The label of a [`cc_variable`](#cc_variable) that should be checked for existence before expanding this rule. If the variable is None, this rule will be ignored.   |  `None` |
| <a id="cc_nested_args-requires_none"></a>requires_none |  (Label) The label of a [`cc_variable`](#cc_variable) that should be checked for non-existence before expanding this rule. If the variable is not None, this rule will be ignored.   |  `None` |
| <a id="cc_nested_args-requires_true"></a>requires_true |  (Label) The label of a [`cc_variable`](#cc_variable) that should be checked for truthiness before expanding this rule. If the variable is false, this rule will be ignored.   |  `None` |
| <a id="cc_nested_args-requires_false"></a>requires_false |  (Label) The label of a [`cc_variable`](#cc_variable) that should be checked for falsiness before expanding this rule. If the variable is true, this rule will be ignored.   |  `None` |
| <a id="cc_nested_args-requires_equal"></a>requires_equal |  (Label) The label of a [`cc_variable`](#cc_variable) that should be checked for equality before expanding this rule. If the variable is not equal to (requires_equal_value)[#cc_nested_args-requires_equal_value], this rule will be ignored.   |  `None` |
| <a id="cc_nested_args-requires_equal_value"></a>requires_equal_value |  (str) The value to compare (requires_equal)[#cc_nested_args-requires_equal] against.   |  `None` |
| <a id="cc_nested_args-kwargs"></a>kwargs |  [common attributes](https://bazel.build/reference/be/common-definitions#common-attributes) that should be applied to this rule.   |  none |


<a id="cc_tool_map"></a>

## cc_tool_map

<pre>
cc_tool_map(<a href="#cc_tool_map-name">name</a>, <a href="#cc_tool_map-tools">tools</a>, <a href="#cc_tool_map-kwargs">kwargs</a>)
</pre>

A toolchain configuration rule that maps toolchain actions to tools.

A [`cc_tool_map`](#cc_tool_map) aggregates all the tools that may be used for a given toolchain
and maps them to their corresponding actions. Conceptually, this is similar to the
`CXX=/path/to/clang++` environment variables that most build systems use to determine which
tools to use for a given action. To simplify usage, some actions have been grouped together (for
example,
[@rules_cc//cc/toolchains/actions:cpp_compile_actions](https://github.com/bazelbuild/rules_cc/tree/main/cc/toolchains/actions/BUILD)) to
logically express "all the C++ compile actions".

In Bazel, there is a little more granularity to the mapping, so the mapping doesn't follow the
traditional `CXX`, `AR`, etc. naming scheme. For a comprehensive list of all the well-known
actions, see @rules_cc//cc/toolchains/actions:BUILD.

Example usage:
```
load("@rules_cc//cc/toolchains:tool_map.bzl", "cc_tool_map")

cc_tool_map(
    name = "all_tools",
    tools = {
        "@rules_cc//cc/toolchains/actions:assembly_actions": ":asm",
        "@rules_cc//cc/toolchains/actions:c_compile": ":clang",
        "@rules_cc//cc/toolchains/actions:cpp_compile_actions": ":clang++",
        "@rules_cc//cc/toolchains/actions:link_actions": ":lld",
        "@rules_cc//cc/toolchains/actions:objcopy_embed_data": ":llvm-objcopy",
        "@rules_cc//cc/toolchains/actions:strip": ":llvm-strip",
        "@rules_cc//cc/toolchains/actions:ar_actions": ":llvm-ar",
    },
)
```

Note:
   Due to an implementation limitation, if you need to map the same tool to multiple actions,
   you will need to create an intermediate alias for the tool for each set of actions. See
   https://github.com/bazelbuild/rules_cc/issues/235 for more details.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="cc_tool_map-name"></a>name |  (str) The name of the target.   |  none |
| <a id="cc_tool_map-tools"></a>tools |  (Dict[Label, Label]) A mapping between [`cc_action_type`](#cc_action_type)/[`cc_action_type_set`](#cc_action_type_set) targets and the [`cc_tool`](#cc_tool) or executable target that implements that action.   |  none |
| <a id="cc_tool_map-kwargs"></a>kwargs |  [common attributes](https://bazel.build/reference/be/common-definitions#common-attributes) that should be applied to this rule.   |  none |


<a id="cc_variable"></a>

## cc_variable

<pre>
cc_variable(<a href="#cc_variable-name">name</a>, <a href="#cc_variable-type">type</a>, <a href="#cc_variable-kwargs">kwargs</a>)
</pre>

Exposes a toolchain variable to use in toolchain argument expansions.

This internal rule exposes [toolchain variables](https://bazel.build/docs/cc-toolchain-config-reference#cctoolchainconfiginfo-build-variables)
that may be expanded in [`cc_args`](#cc_args) or [`cc_nested_args`](#cc_nested_args)
rules. Because these varaibles merely expose variables inherrent to Bazel,
it's not possible to declare custom variables.

For a full list of available variables, see
[@rules_cc//cc/toolchains/varaibles:BUILD](https://github.com/bazelbuild/rules_cc/tree/main/cc/toolchains/variables/BUILD).

Example:
```
load("@rules_cc//cc/toolchains/impl:variables.bzl", "cc_variable")

# Defines two targets, ":foo" and ":foo.bar"
cc_variable(
    name = "foo",
    type = types.list(types.struct(bar = types.string)),
)
```


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="cc_variable-name"></a>name |  (str) The name of the outer variable, and the rule.   |  none |
| <a id="cc_variable-type"></a>type |  The type of the variable, constructed using `types` factory in [@rules_cc//cc/toolchains/impl:variables.bzl](https://github.com/bazelbuild/rules_cc/tree/main/cc/toolchains/impl/variables.bzl).   |  none |
| <a id="cc_variable-kwargs"></a>kwargs |  [common attributes](https://bazel.build/reference/be/common-definitions#common-attributes) that should be applied to this rule.   |  none |


