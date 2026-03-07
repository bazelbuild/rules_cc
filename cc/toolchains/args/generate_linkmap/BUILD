load("//cc/toolchains:feature.bzl", "cc_feature")
load("//cc/toolchains/impl:args_for_compiler.bzl", "cc_args_for_compiler")

package(default_visibility = ["//visibility:public"])

cc_feature(
    name = "feature",
    args = [
        ":generate_linkmap_windows",
        ":generate_linkmap_generic",
    ],
    feature_name = "generate_linkmap",
)

cc_args_for_compiler(
    name = "generate_linkmap_windows",
    actions = ["//cc/toolchains/actions:link_actions"],
    args = ["/MAP:{output_execpath}.map"],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    format = {"output_execpath": "//cc/toolchains/variables:output_execpath"},
    requires_not_none = "//cc/toolchains/variables:output_execpath",
    visibility = ["//visibility:private"],
)

cc_args_for_compiler(
    name = "generate_linkmap_generic",
    actions = ["//cc/toolchains/actions:link_actions"],
    args = select({
        "@platforms//os:macos": ["-Wl,-map,{output_execpath}.map"],
        "//conditions:default": ["-Wl,-Map={output_execpath}.map"],
    }),
    exclude_compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    format = {"output_execpath": "//cc/toolchains/variables:output_execpath"},
    requires_not_none = "//cc/toolchains/variables:output_execpath",
    visibility = ["//visibility:private"],
)
