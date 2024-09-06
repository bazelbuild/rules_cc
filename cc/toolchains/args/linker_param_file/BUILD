load("//cc/toolchains:args.bzl", "cc_args")
load("//cc/toolchains:args_list.bzl", "cc_args_list")

package(default_visibility = ["//visibility:private"])

cc_args_list(
    name = "linker_param_file",
    args = [":use_param_file"],
    visibility = ["//visibility:public"],
)

cc_args(
    name = "use_param_file",
    actions = [
        "//cc/toolchains/actions:cpp_link_executable",
        "//cc/toolchains/actions:cpp_link_dynamic_library",
        "//cc/toolchains/actions:cpp_link_nodeps_dynamic_library",
        "//cc/toolchains/actions:lto_index_for_executable",
        "//cc/toolchains/actions:lto_index_for_dynamic_library",
        "//cc/toolchains/actions:lto_index_for_nodeps_dynamic_library",
        "//cc/toolchains/actions:cpp_link_static_library",
    ],
    args = ["@{param_file}"],
    format = {"param_file": "//cc/toolchains/variables:linker_param_file"},
    requires_not_none = "//cc/toolchains/variables:linker_param_file",
)
