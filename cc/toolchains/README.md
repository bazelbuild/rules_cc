# Writing a custom rule_based C++ toolchain with rule-based definition.

Work in progress!

This document serves two purposes:
* Until complete, this serves as an agreement for the final user-facing API. 
* Once complete, this will serve as onboarding documentation.

This section will be removed once complete.

## Step 1: Define tools
A tool is simply a binary. Just like any other bazel binary, a tool can specify
additional files required to run.

We can use any bazel binary as an input to anything that requires tools. In the
example below, you could use both clang and ld as tools.

```
# @sysroot//:BUILD
cc_tool(
    name = "clang",
    exe = ":bin/clang",
    execution_requirements = ["requires-mem:24g"],
    data = [...],
)

sh_binary(
    name = "ld",
    srcs = ["ld_wrapper.sh"],
    data = [":bin/ld"],
)
    
```

## Step 2: Generate action configs from those tools
An action config is a mapping from action to:

* A list of tools, (the first one matching the execution requirements is used).
* A list of args and features that are always enabled for the action
* A set of additional files required for the action

Each action can only be specified once in the toolchain. Specifying multiple
actions in a single `cc_action_type_config` is just a shorthand for specifying the
same config for every one of those actions.

If you're already familiar with how to define toolchains, the additional files
is a replacement for `compile_files`, `link_files`, etc.

Additionally, to replace `all_files`, we add `cc_additional_files_for_actions`.
This allows you to specify that particular files are required for particular
actions.

We provide `additional_files` on the `cc_action_type_config` as a shorthand for 
specifying `cc_additional_files_for_actions`

Warning: Implying a feature that is not listed directly in the toolchain will throw
an error. This is to ensure you don't accidentally add a feature to the
toolchain.

```
cc_action_type_config(
    name  = "c_compile",
    actions = ["@rules_cc//actions:all_c_compile"],
    tools = ["@sysroot//:clang"],
    args = [":my_args"],
    implies = [":my_feature"],
    additional_files = ["@sysroot//:all_header_files"],
)

cc_additional_files_for_actions(
    name = "all_action_files",
    actions = ["@rules_cc//actions:all_actions"],
    additional_files = ["@sysroot//:always_needed_files"]
)
```

## Step 3: Define some arguments
Arguments are our replacement for `flag_set` and `env_set`. To add arguments to
our tools, we take heavy inspiration from bazel's
[`Args`](https://bazel.build/rules/lib/builtins/Args) type. We provide the same
API, with the following caveats:
* `actions` specifies which actions the arguments apply to (same as `flag_set`).
* `requires_any_of` is equivalent to `with_features` on the `flag_set`.
* `args` may be used instead of `add` if your command-line is only strings.
* `env` may be used to add environment variables to the arguments. Environment
  variables set by later args take priority.
* By default, all inputs are automatically added to the corresponding actions.
  `additional_files` specifies files that are required for an action when using
  that argument.

```
cc_args(
    name = "inline",
    actions = ["@rules_cc//actions:all_cpp_compile_actions"],
    args = ["--foo"],
    requires_any_of = [":feature"]
    env = {"FOO": "bar"},
    additional_files = [":file"],
)
```

For more complex use cases, we use the same API as `Args`. Values are either:
* A list of files (or a single file for `cc_add_args`).
* Something returning `CcVariableInfo`, which is equivalent to a list of strings.

```
cc_variable(
  name = "bar_baz",
  values = ["bar", "baz"],
)

# Expands to CcVariableInfo(values = ["x86_64-unknown-linux-gnu"])
custom_variable_rule(
  name = "triple",
  ...
)

# Taken from https://bazel.build/rules/lib/builtins/Args#add
cc_add_args(
    name = "single",
    arg_name = "--platform",
    value = ":triple", # Either a single file or a cc_variable
    format = "%s",
)

# Taken from https://bazel.build/rules/lib/builtins/Args#add_all
cc_add_args_all(
    name = "multiple",
    arg_name = "--foo",
    values = [":file", ":file_set"], # Either files or cc_variable.
    # map_each not supported. Write a custom rule if you want that.
    format_each = "%s",
    before_each = "--foo",
    omit_if_empty = True,
    uniquify = False,
    # Expand_directories not yet supported.
    terminate_with = "foo",
)

# Taken from https://bazel.build/rules/lib/builtins/Args#add_joined
cc_add_args_joined(
    name = "joined",
    arg_name = "--foo",
    values = [":file", ":file_set"], # Either files or cc_variable.
    join_with = ",",
    # map_each not supported. Write a custom rule if you want that.
    format_each = "%s",
    format_joined = "--foo=%s",
    omit_if_empty = True,
    uniquify = False,
    # Expand_directories not yet supported.
)

cc_args(
    name = "complex",
    actions = ["@rules_cc//actions:c_compile"],
    add = [":single", ":multiple", ":joined"],
)

cc_args_list(
    name = "all_flags",
    args = [":inline", ":complex"],
)
```

## Step 4: Define some features
A feature is a set of args and configurations that can be enabled or disabled.

Although the existing toolchain recommends using features to avoid duplication
of definitions, we recommend avoiding using features unless you want the user to
be able to enable / disable the feature themselves. This is because we provide
alternatives such as `cc_args_list` to allow combining arguments and
specifying them on each action in the action config.

```
cc_feature(
    name = "my_feature",
    feature_name = "my_feature",
    args = [":all_args"],
    implies = [":other_feature"],
)
```

## Step 5: Generate the toolchain
The `cc_toolchain` macro:

* Performs validation on the inputs (eg. no two action configs for a single
  action)
* Converts the type-safe providers to the unsafe ones in
  `cc_toolchain_config_lib.bzl`
* Generates a set of providers for each of the filegroups respectively
* Generates the appropriate `native.cc_toolchain` invocation.

```
cc_toolchain(
    name = "toolchain",
    features = [":my_feature"]
    unconditional_args = [":all_warnings"],
    action_type_configs = [":c_compile"],
    additional_files = [":all_action_files"],
)
```

# Ancillary components for type-safe toolchains.
## Well-known features
Well-known features will be defined in `@rules_cc//features/well_known:*`.
Any feature with `feature_name` in the well known features will have to specify
overrides.

`cc_toolchain` is aware of the builtin / well-known features. In order to
ensure that a user understands that this overrides the builtin opt feature (I
originally thought that it added extra flags to opt, but you still got the
default ones, so that can definitely happen), and to ensure that they don't
accidentally do so, we will force them to explicitly specify that it overrides
the builtin one. This is essentially just an acknowledgement of "I know what
I'm doing".

Warning: Specifying two features with the same name is an error, unless one
overrides the other. 

```
cc_feature(
    name = "opt",
    ...,
    overrides = "@rules_cc//features/well_known:opt",
)
```

In addition to well-known features, we could also consider in future iterations
to also use known features for partial migrations, where you still imply a
feature that's still defined by the legacy API:

```
# Implementation
def cc_legacy_features(name, features):
  for feature in features:
    cc_known_feature(name = name + "_" + feature.name)
  cc_legacy_features(name = name, features = FEATURES)


# Build file
FOO = feature(name = "foo", args=[arg_group(...)])
FEATURES = [FOO]
cc_legacy_features(name = "legacy_features", features = FEATURES)

cc_feature(name = "bar", implies = [":legacy_features_foo"])

cc_toolchain(
  name = "toolchain",
  legacy_features = ":legacy_features",
  features = [":bar"],
)
```

## Mutual exclusion
Features can be mutually exclusive.

We allow two approaches to mutual exclusion - via features or via categories.

The existing toolchain uses `provides` for both of these. We rename it so that
it makes more sense semantically.

```
cc_feature(
   name = "incompatible_with_my_feature",
   feature_name = "bar",
   mutually_exclusive = [":my_feature"],
)


# This is an example of how we would define compilation mode.
# Since it already exists, this wouldn't work.
cc_mutual_exclusion_category(
    name = "compilation_mode",
)

cc_feature(
    name = "opt",
    ...
    mutually_exclusive = [":compilation_mode"],
)
cc_feature(
    name = "dbg",
    ...
    mutually_exclusive = [":compilation_mode"],
)
```

## Feature requirements
Feature requirements can come in two formats.

For example:

* Features can require some subset of features to be enabled.
* Arguments can require some subset of features to be enabled, but others to be
  disabled.

This is very confusing for toolchain authors, so we will simplify things with
the use of providers:

* `cc_feature` will provide `feature`, `feature_set`, and `with_feature`
* `cc_feature_set` will provide `feature_set` and `with_feature`.
* `cc_feature_constraint` will provide `with_features` only.

We will rename all `with_features` and `requires` to `requires_any_of`, to make
it very clear that only one of the requirements needs to be met.

```
cc_feature_set(
    name = "my_feature_set",
    all_of = [":my_feature"],
)

cc_feature_constraint(
    name = "my_feature_constraint",
    all_of = [":my_feature"],
    none_of = [":my_other_feature"],
)

cc_args(
   name = "foo",
   # All of these provide with_feature.
   requires_any_of = [":my_feature", ":my_feature_set", ":my_feature_constraint"]
)

# my_feature_constraint would be an error here.
cc_feature(
   name = "foo",
   # Both of these provide feature_set.
   requires_any_of = [":my_feature", ":my_feature_set"]
   implies = [":my_other_feature", :my_other_feature_set"],
)
```
