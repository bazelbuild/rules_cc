load("//cc/toolchains:feature.bzl", "cc_feature")

package(default_visibility = ["//visibility:public"])

# All of these arguments originate from the legacy features defined in Bazel's Java code:
#     https://github.com/bazelbuild/bazel/blob/master/src/main/java/com/google/devtools/build/lib/rules/cpp/CppActionConfigs.java

# This feature replaces the need for action configs to list legacy features
# in `implies` to produce a working toolchain. The full list is the set of
# features that are implied (enabled) by built-in action  config definitions.
# Note that some other legacy features are still hidden and enabled by default,
# and others exist that are NOT enabled at all by default. As args are built
# out, the `implies` entry should be removed and then moved into `args`.
cc_feature(
    name = "experimental_replace_legacy_action_config_features",
    args = [
        "//cc/toolchains/args/archiver_flags",
        "//cc/toolchains/args/force_pic_flags",
        "//cc/toolchains/args/libraries_to_link",
        "//cc/toolchains/args/linker_param_file",
        "//cc/toolchains/args/runtime_library_search_directories",
        "//cc/toolchains/args/shared_flag",
    ],
    feature_name = "experimental_replace_legacy_action_config_features",
    # TODO: Convert remaining items in this list into their actual args.
    implies = [
        "//cc/toolchains/features/legacy:build_interface_libraries",
        "//cc/toolchains/features/legacy:compiler_input_flags",
        "//cc/toolchains/features/legacy:compiler_output_flags",
        "//cc/toolchains/features/legacy:dynamic_library_linker_tool",
        "//cc/toolchains/features/legacy:fission_support",
        "//cc/toolchains/features/legacy:legacy_compile_flags",
        "//cc/toolchains/features/legacy:legacy_link_flags",
        "//cc/toolchains/features/legacy:library_search_directories",
        "//cc/toolchains/features/legacy:linkstamps",
        "//cc/toolchains/features/legacy:output_execpath_flags",
        "//cc/toolchains/features/legacy:strip_debug_symbols",
        "//cc/toolchains/features/legacy:unfiltered_compile_flags",
        "//cc/toolchains/features/legacy:user_compile_flags",
        "//cc/toolchains/features/legacy:user_link_flags",
    ],
)
