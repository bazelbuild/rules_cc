load("//cc/toolchains:args_list.bzl", "cc_args_list")
load("//cc/toolchains:feature.bzl", "cc_feature")
load("//cc/toolchains:nested_args.bzl", "cc_nested_args")
load("//cc/toolchains/args/libraries_to_link/private:library_link_args.bzl", "library_link_args")
load("//cc/toolchains/impl:args_for_compiler.bzl", "cc_args_for_compiler")

package(default_visibility = ["//visibility:private"])

cc_feature(
    name = "feature",
    args = [":libraries_to_link"],
    overrides = "//cc/toolchains/features/legacy:libraries_to_link",
    visibility = ["//visibility:public"],
)

cc_args_list(
    name = "libraries_to_link",
    args = [
        ":libraries_to_link_generic",
        ":libraries_to_link_windows",
    ],
    visibility = ["//visibility:public"],
)

cc_args_for_compiler(
    name = "libraries_to_link_generic",
    actions = ["//cc/toolchains/actions:link_actions"],
    exclude_compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    nested = [
        ":thinlto_param_file",
        ":libraries_to_link_args_generic",
    ],
)

cc_args_for_compiler(
    name = "libraries_to_link_windows",
    actions = ["//cc/toolchains/actions:link_actions"],
    compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    nested = [
        ":thinlto_param_file",
        ":libraries_to_link_args_windows",
    ],
)

cc_nested_args(
    name = "thinlto_param_file",
    args = ["-Wl,@{param_file}"],
    format = {
        "param_file": "//cc/toolchains/variables:thinlto_param_file",
    },
    requires_not_none = "//cc/toolchains/variables:thinlto_param_file",
)

cc_nested_args(
    name = "libraries_to_link_args_generic",
    nested = [":iterate_over_libraries_to_link_generic"],
    requires_not_none = "//cc/toolchains/variables:libraries_to_link",
)

cc_nested_args(
    name = "iterate_over_libraries_to_link_generic",
    iterate_over = "//cc/toolchains/variables:libraries_to_link",
    nested = [
        ":optional_object_file_group_start",
        ":single_library_args_generic",
        ":optional_object_file_group_end",
    ],
)

cc_nested_args(
    name = "libraries_to_link_args_windows",
    nested = [":iterate_over_libraries_to_link_windows"],
    requires_not_none = "//cc/toolchains/variables:libraries_to_link",
)

cc_nested_args(
    name = "iterate_over_libraries_to_link_windows",
    iterate_over = "//cc/toolchains/variables:libraries_to_link",
    nested = [
        ":single_library_args_windows",
    ],
)

cc_nested_args(
    name = "optional_object_file_group_start",
    nested = [":start_lib_arg"],
    requires_equal = "//cc/toolchains/variables:libraries_to_link.type",
    requires_equal_value = "object_file_group",
)

cc_nested_args(
    name = "start_lib_arg",
    args = ["-Wl,--start-lib"],
    requires_false = "//cc/toolchains/variables:libraries_to_link.is_whole_archive",
)

cc_nested_args(
    name = "optional_object_file_group_end",
    nested = [":end_lib_arg"],
    requires_equal = "//cc/toolchains/variables:libraries_to_link.type",
    requires_equal_value = "object_file_group",
)

cc_nested_args(
    name = "end_lib_arg",
    args = ["-Wl,--end-lib"],
    requires_false = "//cc/toolchains/variables:libraries_to_link.is_whole_archive",
)

cc_nested_args(
    name = "single_library_args_generic",
    nested = select({
        "@platforms//os:macos": [],
        "//conditions:default": [":optional_whole_archive_start"],
    }) + [
        ":optional_object_file_group",
        ":optional_object_file",
        ":optional_interface_library",
        ":optional_static_library",
        ":optional_dynamic_library",
    ] + select({
        # macOS has a minor nuance where it uses the path to the library instead of `-l:{library_name}`.
        "@platforms//os:macos": [":macos_optional_versioned_dynamic_library"],
        "//conditions:default": [":generic_optional_versioned_dynamic_library"],
    }) + select({
        "@platforms//os:macos": [],
        "//conditions:default": [":optional_whole_archive_end"],
    }),
)

cc_nested_args(
    name = "single_library_args_windows",
    nested = [
        ":windows_optional_object_file_group",
        ":windows_optional_object_file",
        ":windows_optional_interface_library",
        ":windows_optional_static_library",
    ],
)

cc_nested_args(
    name = "windows_optional_object_file_group",
    args = ["{library}"],
    format = {
        "library": "//cc/toolchains/variables:libraries_to_link.object_files",
    },
    iterate_over = "//cc/toolchains/variables:libraries_to_link.object_files",
    requires_equal = "//cc/toolchains/variables:libraries_to_link.type",
    requires_equal_value = "object_file_group",
)

cc_nested_args(
    name = "windows_optional_object_file",
    args = ["{library}"],
    format = {
        "library": "//cc/toolchains/variables:libraries_to_link.name",
    },
    requires_equal = "//cc/toolchains/variables:libraries_to_link.type",
    requires_equal_value = "object_file",
)

cc_nested_args(
    name = "windows_optional_interface_library",
    args = ["{library}"],
    format = {
        "library": "//cc/toolchains/variables:libraries_to_link.name",
    },
    requires_equal = "//cc/toolchains/variables:libraries_to_link.type",
    requires_equal_value = "interface_library",
)

cc_nested_args(
    name = "windows_optional_static_library",
    nested = [
        ":windows_static_library_whole_archive",
        ":windows_static_library_no_whole_archive",
    ],
    requires_equal = "//cc/toolchains/variables:libraries_to_link.type",
    requires_equal_value = "static_library",
)

cc_nested_args(
    name = "windows_static_library_no_whole_archive",
    args = ["{library}"],
    format = {
        "library": "//cc/toolchains/variables:libraries_to_link.name",
    },
    requires_false = "//cc/toolchains/variables:libraries_to_link.is_whole_archive",
)

cc_nested_args(
    name = "windows_static_library_whole_archive",
    args = ["/WHOLEARCHIVE:{library}"],
    format = {
        "library": "//cc/toolchains/variables:libraries_to_link.name",
    },
    requires_true = "//cc/toolchains/variables:libraries_to_link.is_whole_archive",
)

cc_nested_args(
    name = "optional_whole_archive_start",
    nested = [":whole_archive_start_arg"],
    requires_true = "//cc/toolchains/variables:libraries_to_link.is_whole_archive",
)

cc_nested_args(
    name = "whole_archive_start_arg",
    args = ["-Wl,-whole-archive"],
    requires_equal = "//cc/toolchains/variables:libraries_to_link.type",
    requires_equal_value = "static_library",
)

cc_nested_args(
    name = "optional_whole_archive_end",
    nested = [":whole_archive_end_arg"],
    requires_true = "//cc/toolchains/variables:libraries_to_link.is_whole_archive",
)

cc_nested_args(
    name = "whole_archive_end_arg",
    args = ["-Wl,-no-whole-archive"],
    requires_equal = "//cc/toolchains/variables:libraries_to_link.type",
    requires_equal_value = "static_library",
)

library_link_args(
    name = "optional_object_file_group",
    from_variable = "//cc/toolchains/variables:libraries_to_link.object_files",
    iterate_over_variable = True,
    library_type = "object_file_group",
)

library_link_args(
    name = "optional_object_file",
    from_variable = "//cc/toolchains/variables:libraries_to_link.name",
    library_type = "object_file",
)

library_link_args(
    name = "optional_interface_library",
    from_variable = "//cc/toolchains/variables:libraries_to_link.name",
    library_type = "interface_library",
)

library_link_args(
    name = "optional_static_library",
    from_variable = "//cc/toolchains/variables:libraries_to_link.name",
    library_type = "static_library",
)

cc_nested_args(
    name = "optional_dynamic_library",
    args = ["-l{library}"],
    format = {
        "library": "//cc/toolchains/variables:libraries_to_link.name",
    },
    requires_equal = "//cc/toolchains/variables:libraries_to_link.type",
    requires_equal_value = "dynamic_library",
)

cc_nested_args(
    name = "generic_optional_versioned_dynamic_library",
    args = ["-l:{library_name}"],
    format = {
        "library_name": "//cc/toolchains/variables:libraries_to_link.name",
    },
    requires_equal = "//cc/toolchains/variables:libraries_to_link.type",
    requires_equal_value = "versioned_dynamic_library",
)

cc_nested_args(
    name = "macos_optional_versioned_dynamic_library",
    args = ["{library_path}"],
    format = {
        "library_path": "//cc/toolchains/variables:libraries_to_link.path",
    },
    requires_equal = "//cc/toolchains/variables:libraries_to_link.type",
    requires_equal_value = "versioned_dynamic_library",
)
