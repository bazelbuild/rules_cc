load(":compare_feature.bzl", "compare_feature_implementation")
load(":goldens/macos/archiver_flags.bzl", _MACOS_ARCHIVER_FLAGS = "GOLDEN")
load(":goldens/macos/force_pic_flags.bzl", _MACOS_FORCE_PIC_FLAGS = "GOLDEN")
load(":goldens/macos/libraries_to_link.bzl", _MACOS_LIBRARIES_TO_LINK = "GOLDEN")
load(":goldens/macos/runtime_library_search_directories.bzl", _MACOS_RUNTIME_LIBRARY_SEARCH_DIRECTORIES = "GOLDEN")
load(":goldens/unix/archiver_flags.bzl", _UNIX_ARCHIVER_FLAGS = "GOLDEN")
load(":goldens/unix/force_pic_flags.bzl", _UNIX_FORCE_PIC_FLAGS = "GOLDEN")
load(":goldens/unix/libraries_to_link.bzl", _UNIX_LIBRARIES_TO_LINK = "GOLDEN")
load(":goldens/unix/linker_param_file.bzl", _UNIX_LINKER_PARAM_FILE = "GOLDEN")
load(":goldens/unix/runtime_library_search_directories.bzl", _UNIX_RUNTIME_LIBRARY_SEARCH_DIRECTORIES = "GOLDEN")
load(":goldens/unix/shared_flag.bzl", _UNIX_SHARED_FLAG = "GOLDEN")

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
    expected = _MACOS_ARCHIVER_FLAGS,
    feature_name = "archiver_flags_test",
    platform = ":macos",
)

compare_feature_implementation(
    name = "archiver_flags_unix_test",
    actual_implementation = "//cc/toolchains/args/archiver_flags",
    expected = _UNIX_ARCHIVER_FLAGS,
    feature_name = "archiver_flags_test",
    platform = ":linux",
)

compare_feature_implementation(
    name = "force_pic_flags_macos_test",
    actual_implementation = "//cc/toolchains/args/pic_flags:force_pic_flags",
    expected = _MACOS_FORCE_PIC_FLAGS,
    feature_name = "force_pic_flags_test",
    platform = ":macos",
)

compare_feature_implementation(
    name = "force_pic_flags_unix_test",
    actual_implementation = "//cc/toolchains/args/pic_flags:force_pic_flags",
    expected = _UNIX_FORCE_PIC_FLAGS,
    feature_name = "force_pic_flags_test",
    platform = ":linux",
)

compare_feature_implementation(
    name = "libraries_to_link_macos_test",
    actual_implementation = "//cc/toolchains/args/libraries_to_link",
    expected = _MACOS_LIBRARIES_TO_LINK,
    feature_name = "libraries_to_link_test",
    platform = ":macos",
)

compare_feature_implementation(
    name = "libraries_to_link_unix_test",
    actual_implementation = "//cc/toolchains/args/libraries_to_link",
    expected = _UNIX_LIBRARIES_TO_LINK,
    feature_name = "libraries_to_link_test",
    platform = ":linux",
)

compare_feature_implementation(
    name = "linker_param_file_test",
    actual_implementation = "//cc/toolchains/args/linker_param_file",
    expected = _UNIX_LINKER_PARAM_FILE,
    feature_name = "linker_param_file_test",
    platform = ":linux",
)

compare_feature_implementation(
    name = "runtime_library_search_directories_macos_test",
    actual_implementation = "//cc/toolchains/args/runtime_library_search_directories",
    expected = _MACOS_RUNTIME_LIBRARY_SEARCH_DIRECTORIES,
    feature_name = "runtime_library_search_directories_test",
    platform = ":macos",
)

compare_feature_implementation(
    name = "runtime_library_search_directories_unix_test",
    actual_implementation = "//cc/toolchains/args/runtime_library_search_directories",
    expected = _UNIX_RUNTIME_LIBRARY_SEARCH_DIRECTORIES,
    feature_name = "runtime_library_search_directories_test",
    platform = ":linux",
)

compare_feature_implementation(
    name = "shared_flag_test",
    actual_implementation = "//cc/toolchains/args/shared_flag",
    expected = _UNIX_SHARED_FLAG,
    feature_name = "shared_flag_test",
    platform = ":linux",
)
