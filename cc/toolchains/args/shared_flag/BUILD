load("//cc/toolchains:args.bzl", "cc_args")

package(default_visibility = ["//visibility:private"])

cc_args(
    name = "shared_flag",
    actions = [
        "//cc/toolchains/actions:cpp_link_dynamic_library",
        "//cc/toolchains/actions:cpp_link_nodeps_dynamic_library",
        "//cc/toolchains/actions:lto_index_for_dynamic_library",
        "//cc/toolchains/actions:lto_index_for_nodeps_dynamic_library",
    ],
    args = ["-shared"],
    visibility = ["//visibility:public"],
)
