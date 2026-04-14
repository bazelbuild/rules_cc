load("//cc/toolchains:actions.bzl", "cc_action_type_set")
load("//cc/toolchains:args.bzl", "cc_args")
load("//cc/toolchains:feature.bzl", "cc_feature")

cc_action_type_set(
    name = "lto_index_actions",
    actions = [
        "//cc/toolchains/actions:lto_index_for_executable",
        "//cc/toolchains/actions:lto_index_for_dynamic_library",
        "//cc/toolchains/actions:lto_index_for_nodeps_dynamic_library",
    ],
)

cc_args(
    name = "lto_flag",
    actions = [
        ":lto_index_actions",
        "//cc/toolchains/actions:c_compile",
        "//cc/toolchains/actions:cpp_compile",
        "//cc/toolchains/actions:link_actions",
    ],
    args = [
        "-flto=thin",
    ],
)

cc_args(
    name = "indexing_bitcode_file_flags",
    actions = [
        "//cc/toolchains/actions:compile_actions",
    ],
    args = [
        "-Xclang",
        "-fthin-link-bitcode={lto_indexing_bitcode_file}",
    ],
    format = {
        "lto_indexing_bitcode_file": "//cc/toolchains/variables:lto_indexing_bitcode_file",
    },
    requires_not_none = "//cc/toolchains/variables:lto_indexing_bitcode_file",
)

cc_args(
    name = "indexing_param_file_flags",
    actions = [
        ":lto_index_actions",
    ],
    args = [
        "-Wl,-plugin-opt,thinlto-index-only={thinlto_indexing_param_file}",
    ],
    format = {
        "thinlto_indexing_param_file": "//cc/toolchains/variables:thinlto_indexing_param_file",
    },
    requires_not_none = "//cc/toolchains/variables:thinlto_indexing_param_file",
)

cc_args(
    name = "emit_imports_files_flags",
    actions = [
        ":lto_index_actions",
    ],
    args = [
        "-Wl,-plugin-opt,thinlto-emit-imports-files",
    ],
)

cc_args(
    name = "prefix_replace_flags",
    actions = [
        ":lto_index_actions",
    ],
    args = [
        "-Wl,-plugin-opt,thinlto-prefix-replace={thinlto_prefix_replace}",
    ],
    format = {
        "thinlto_prefix_replace": "//cc/toolchains/variables:thinlto_prefix_replace",
    },
    requires_not_none = "//cc/toolchains/variables:thinlto_prefix_replace",
)

cc_args(
    name = "object_suffix_replace_flags",
    actions = [
        ":lto_index_actions",
    ],
    args = [
        "-Wl,-plugin-opt,thinlto-object-suffix-replace={thinlto_object_suffix_replace}",
    ],
    format = {
        "thinlto_object_suffix_replace": "//cc/toolchains/variables:thinlto_object_suffix_replace",
    },
    requires_not_none = "//cc/toolchains/variables:thinlto_object_suffix_replace",
)

cc_args(
    name = "merged_object_file_flags",
    actions = [
        ":lto_index_actions",
    ],
    args = [
        "-Wl,-plugin-opt,obj-path={thinlto_merged_object_file}",
    ],
    format = {
        "thinlto_merged_object_file": "//cc/toolchains/variables:thinlto_merged_object_file",
    },
    requires_not_none = "//cc/toolchains/variables:thinlto_merged_object_file",
)

cc_args(
    name = "index_flags",
    actions = [
        "//cc/toolchains/actions:lto_backend",
    ],
    args = [
        "-c",
        "-fthinlto-index={thinlto_index}",
    ],
    format = {
        "thinlto_index": "//cc/toolchains/variables:thinlto_index",
    },
    requires_not_none = "//cc/toolchains/variables:thinlto_index",
)

cc_args(
    name = "output_object_file_flags",
    actions = [
        "//cc/toolchains/actions:lto_backend",
    ],
    args = [
        "-o",
        "{thinlto_output_object_file}",
    ],
    format = {
        "thinlto_output_object_file": "//cc/toolchains/variables:thinlto_output_object_file",
    },
    requires_not_none = "//cc/toolchains/variables:thinlto_output_object_file",
)

cc_args(
    name = "input_bitcode_file_flags",
    actions = [
        "//cc/toolchains/actions:lto_backend",
    ],
    args = [
        "-x",
        "ir",
        "{thinlto_input_bitcode_file}",
    ],
    format = {
        "thinlto_input_bitcode_file": "//cc/toolchains/variables:thinlto_input_bitcode_file",
    },
    requires_not_none = "//cc/toolchains/variables:thinlto_input_bitcode_file",
)

cc_feature(
    name = "feature",
    args = [
        ":lto_flag",
        ":indexing_bitcode_file_flags",
        ":merged_object_file_flags",
        ":index_flags",
        ":output_object_file_flags",
        ":input_bitcode_file_flags",
        ":indexing_param_file_flags",
        ":emit_imports_files_flags",
        ":prefix_replace_flags",
        ":object_suffix_replace_flags",
    ],
    feature_name = "thin_lto",
    visibility = ["//visibility:public"],
)
