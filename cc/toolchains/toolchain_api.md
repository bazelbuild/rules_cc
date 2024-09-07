<!-- Generated with Stardoc: http://skydoc.bazel.build -->

This is a list of rules/macros that should be exported as documentation.

<a id="cc_tool_map"></a>

## cc_tool_map

<pre>
cc_tool_map(<a href="#cc_tool_map-name">name</a>, <a href="#cc_tool_map-tools">tools</a>, <a href="#cc_tool_map-kwargs">kwargs</a>)
</pre>

A toolchain configuration rule that maps toolchain actions to tools.

A cc_tool_map aggregates all the tools that may be used for a given toolchain and maps them to
their corresponding actions. Conceptually, this is similar to the `CXX=/path/to/clang++`
environment variables that most build systems use to determine which tools to use for a given
action. To simplify usage, some actions have been grouped together (for example,
//third_party/bazel_rules/rules_cc/cc/toolchains/actions:cpp_compile_actions) to
logically express "all the C++ compile actions".

In Bazel, there is a little more granularity to the mapping, so the mapping doesn't follow the
traditional `CXX`, `AR`, etc. naming scheme. For a comprehensive list of all the well-known
actions, see //third_party/bazel_rules/rules_cc/cc/toolchains/actions:BUILD.

Example usage:
```
load("//third_party/bazel_rules/rules_cc/cc/toolchains:tool_map.bzl", "cc_tool_map")

cc_tool_map(
    name = "all_tools",
    tools = {
        "//third_party/bazel_rules/rules_cc/cc/toolchains/actions:assembly_actions": ":asm",
        "//third_party/bazel_rules/rules_cc/cc/toolchains/actions:c_compile": ":clang",
        "//third_party/bazel_rules/rules_cc/cc/toolchains/actions:cpp_compile_actions": ":clang++",
        "//third_party/bazel_rules/rules_cc/cc/toolchains/actions:link_actions": ":lld",
        "//third_party/bazel_rules/rules_cc/cc/toolchains/actions:objcopy_embed_data": ":llvm-objcopy",
        "//third_party/bazel_rules/rules_cc/cc/toolchains/actions:strip": ":llvm-strip",
        "//third_party/bazel_rules/rules_cc/cc/toolchains/actions:ar_actions": ":llvm-ar",
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
| <a id="cc_tool_map-tools"></a>tools |  (Dict[target providing ActionTypeSetInfo, Executable target]) A mapping between `cc_action_type` targets and the `cc_tool` or executable target that implements that action.   |  none |
| <a id="cc_tool_map-kwargs"></a>kwargs |  [common attributes](https://bazel.build/reference/be/common-definitions#common-attributes) that should be applied to this rule.   |  none |


