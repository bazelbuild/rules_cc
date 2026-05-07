load(":compare_feature.bzl", "compare_feature_implementation")
load(":goldens.bzl", "GOLDENS")

# These tests validate that the produced legacy feature implementations
# properly reflect the implementations housed in the Java source of truth at
# https://github.com/bazelbuild/bazel/blob/master/src/main/java/com/google/devtools/build/lib/rules/cpp/CppActionConfigs.java.
#
# Note: the golden textproto strings are not a 1:1 match of the textprotos inlined in
# the Java files. These aim to have identical behavior, but with allowance
# for slight differences in structure due to implementation details. This also
# makes it easier to review the final results.

platform(
    name = "linux",
    constraint_values = [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
    ],
)

platform(
    name = "macos",
    constraint_values = [
        "@platforms//os:macos",
        "@platforms//cpu:x86_64",
    ],
)

compare_feature_implementation(
    name = "archiver_flags_macos_test",
    actual_implementation = "//cc/toolchains/args/archiver_flags",
    expected = GOLDENS["macos/archiver_flags"],
    feature_name = "archiver_flags_test",
    platform = ":macos",
)

compare_feature_implementation(
    name = "archiver_flags_unix_test",
    actual_implementation = "//cc/toolchains/args/archiver_flags",
    expected = GOLDENS["unix/archiver_flags"],
    feature_name = "archiver_flags_test",
    platform = ":linux",
)

compare_feature_implementation(
    name = "force_pic_flags_macos_test",
    actual_implementation = "//cc/toolchains/args/pic_flags:force_pic_flags",
    expected = GOLDENS["macos/force_pic_flags"],
    feature_name = "force_pic_flags_test",
    platform = ":macos",
)

compare_feature_implementation(
    name = "force_pic_flags_unix_test",
    actual_implementation = "//cc/toolchains/args/pic_flags:force_pic_flags",
    expected = GOLDENS["unix/force_pic_flags"],
    feature_name = "force_pic_flags_test",
    platform = ":linux",
)

compare_feature_implementation(
    name = "libraries_to_link_macos_test",
    actual_implementation = "//cc/toolchains/args/libraries_to_link",
    expected = GOLDENS["macos/libraries_to_link"],
    feature_name = "libraries_to_link_test",
    platform = ":macos",
)

compare_feature_implementation(
    name = "libraries_to_link_unix_test",
    actual_implementation = "//cc/toolchains/args/libraries_to_link",
    expected = GOLDENS["unix/libraries_to_link"],
    feature_name = "libraries_to_link_test",
    platform = ":linux",
)

compare_feature_implementation(
    name = "linker_param_file_test",
    actual_implementation = "//cc/toolchains/args/linker_param_file",
    expected = GOLDENS["unix/linker_param_file"],
    feature_name = "linker_param_file_test",
    platform = ":linux",
)

compare_feature_implementation(
    name = "runtime_library_search_directories_macos_test",
    actual_implementation = "//cc/toolchains/args/runtime_library_search_directories",
    expected = GOLDENS["macos/runtime_library_search_directories"],
    feature_name = "runtime_library_search_directories_test",
    platform = ":macos",
)

compare_feature_implementation(
    name = "runtime_library_search_directories_unix_test",
    actual_implementation = "//cc/toolchains/args/runtime_library_search_directories",
    expected = GOLDENS["unix/runtime_library_search_directories"],
    feature_name = "runtime_library_search_directories_test",
    platform = ":linux",
)

compare_feature_implementation(
    name = "shared_flag_test",
    actual_implementation = "//cc/toolchains/args/shared_flag",
    expected = GOLDENS["unix/shared_flag"],
    feature_name = "shared_flag_test",
    platform = ":linux",
)
