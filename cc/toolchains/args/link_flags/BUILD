load("//cc/toolchains:args.bzl", "cc_args")
load("//cc/toolchains:feature.bzl", "cc_feature")
load("//cc/toolchains:feature_set.bzl", "cc_feature_set")
load("//cc/toolchains:nested_args.bzl", "cc_nested_args")

cc_feature_set(
    name = "feature",
    all_of = [
        ":user_link_flags_feature",
        ":legacy_link_flags_feature",
        ":output_link_flags_feature",
        ":build_interface_libraries_feature",
        ":dynamic_library_linker_tool_feature",
    ],
    visibility = ["//visibility:public"],
)

cc_feature(
    name = "legacy_link_flags_feature",
    args = [":legacy_link_flags"],
    overrides = "//cc/toolchains/features/legacy:legacy_link_flags",
)

cc_args(
    name = "legacy_link_flags",
    actions = ["//cc/toolchains/actions:link_actions"],
    args = ["{legacy_link_flags}"],
    format = {"legacy_link_flags": "//cc/toolchains/variables:legacy_link_flags"},
    iterate_over = "//cc/toolchains/variables:legacy_link_flags",
    requires_not_none = "//cc/toolchains/variables:legacy_link_flags",
)

cc_feature(
    name = "user_link_flags_feature",
    args = [":user_link_flags"],
    overrides = "//cc/toolchains/features/legacy:user_link_flags",
)

cc_args(
    name = "user_link_flags",
    actions = ["//cc/toolchains/actions:link_actions"],
    args = ["{user_link_flags}"],
    format = {"user_link_flags": "//cc/toolchains/variables:user_link_flags"},
    iterate_over = "//cc/toolchains/variables:user_link_flags",
    requires_not_none = "//cc/toolchains/variables:user_link_flags",
)

cc_feature(
    name = "output_link_flags_feature",
    args = [":output_link_flags"],
    overrides = "//cc/toolchains/features/legacy:output_execpath_flags",
)

cc_args(
    name = "output_link_flags",
    actions = ["//cc/toolchains/actions:link_actions"],
    args = [
        "-o",
        "{output_execpath}",
    ],
    format = {"output_execpath": "//cc/toolchains/variables:output_execpath"},
    requires_not_none = "//cc/toolchains/variables:output_execpath",
)

cc_feature(
    name = "build_interface_libraries_feature",
    args = ["build_interface_libraries"],
    overrides = "//cc/toolchains/features/legacy:build_interface_libraries",
)

cc_args(
    name = "build_interface_libraries",
    actions = ["//cc/toolchains/actions:dynamic_library_link_actions"],
    nested = [":build_interface_libraries_check"],
    requires_not_none = "//cc/toolchains/variables:generate_interface_library",
)

cc_nested_args(
    name = "build_interface_libraries_check",
    nested = select({
        "@platforms//os:windows": [":windows_build_interface_libraries"],
        "//conditions:default": [":generic_build_interface_libraries"],
    }),
    requires_equal = "//cc/toolchains/variables:generate_interface_library",
    requires_equal_value = "yes",
)

cc_nested_args(
    name = "windows_build_interface_libraries",
    args = ["-Wl,/IMPLIB:{interface_library_output_path}"],
    format = {"interface_library_output_path": "//cc/toolchains/variables:interface_library_output_path"},
    requires_not_none = "//cc/toolchains/variables:interface_library_output_path",
)

cc_nested_args(
    name = "generic_build_interface_libraries",
    nested = [
        ":generate_interface_library",
        ":interface_library_builder_path",
        ":interface_library_input_path",
        ":interface_library_output_path",
    ],
)

cc_nested_args(
    name = "generate_interface_library",
    args = ["{generate_interface_library}"],
    format = {"generate_interface_library": "//cc/toolchains/variables:generate_interface_library"},
)

cc_nested_args(
    name = "interface_library_builder_path",
    args = ["{interface_library_builder_path}"],
    format = {"interface_library_builder_path": "//cc/toolchains/variables:interface_library_builder_path"},
    requires_not_none = "//cc/toolchains/variables:interface_library_builder_path",
)

cc_nested_args(
    name = "interface_library_input_path",
    args = ["{interface_library_input_path}"],
    format = {"interface_library_input_path": "//cc/toolchains/variables:interface_library_input_path"},
    requires_not_none = "//cc/toolchains/variables:interface_library_input_path",
)

cc_nested_args(
    name = "interface_library_output_path",
    args = ["{interface_library_output_path}"],
    format = {"interface_library_output_path": "//cc/toolchains/variables:interface_library_output_path"},
    requires_not_none = "//cc/toolchains/variables:interface_library_output_path",
)

cc_feature(
    name = "dynamic_library_linker_tool_feature",
    args = select({
        "@platforms//os:windows": [],
        "//conditions:default": ["dynamic_library_linker_tool"],
    }),
    overrides = "//cc/toolchains/features/legacy:dynamic_library_linker_tool",
)

cc_args(
    name = "dynamic_library_linker_tool",
    actions = ["//cc/toolchains/actions:dynamic_library_link_actions"],
    nested = [":dynamic_library_linker_tool_check"],
    requires_not_none = "//cc/toolchains/variables:generate_interface_library",
)

cc_nested_args(
    name = "dynamic_library_linker_tool_check",
    args = [" + cppLinkDynamicLibraryToolPath + "],
    requires_equal = "//cc/toolchains/variables:generate_interface_library",
    requires_equal_value = "yes",
)
