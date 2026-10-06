load("//cc/toolchains/args:sysroot.bzl", "cc_sysroot")
load(":compare_feature.bzl", "compare_cc_feature_implementation", "compare_feature_implementation")
load(":goldens/macos/archiver_flags.bzl", _MACOS_ARCHIVER_FLAGS = "GOLDEN")
load(":goldens/macos/force_pic_flags.bzl", _MACOS_FORCE_PIC_FLAGS = "GOLDEN")
load(":goldens/macos/libraries_to_link.bzl", _MACOS_LIBRARIES_TO_LINK = "GOLDEN")
load(":goldens/macos/runtime_library_search_directories.bzl", _MACOS_RUNTIME_LIBRARY_SEARCH_DIRECTORIES = "GOLDEN")
load(":goldens/macos/thin_lto.bzl", _MACOS_THIN_LTO = "GOLDEN")
load(":goldens/unix/archiver_flags.bzl", _UNIX_ARCHIVER_FLAGS = "GOLDEN")
load(":goldens/unix/external_include_paths.bzl", _UNIX_EXTERNAL_INCLUDE_PATHS = "GOLDEN")
load(":goldens/unix/force_pic_flags.bzl", _UNIX_FORCE_PIC_FLAGS = "GOLDEN")
load(":goldens/unix/include_paths.bzl", _UNIX_INCLUDE_PATHS = "GOLDEN")
load(":goldens/unix/includes.bzl", _UNIX_INCLUDES = "GOLDEN")
load(":goldens/unix/layering_check.bzl", _UNIX_LAYERING_CHECK = "GOLDEN")
load(":goldens/unix/libraries_to_link.bzl", _UNIX_LIBRARIES_TO_LINK = "GOLDEN")
load(":goldens/unix/linker_param_file.bzl", _UNIX_LINKER_PARAM_FILE = "GOLDEN")
load(":goldens/unix/per_object_debug_info.bzl", _UNIX_PER_OBJECT_DEBUG_INFO = "GOLDEN")
load(":goldens/unix/pic.bzl", _UNIX_PIC = "GOLDEN")
load(":goldens/unix/preprocessor_defines.bzl", _UNIX_PREPROCESSOR_DEFINES = "GOLDEN")
load(":goldens/unix/random_seed.bzl", _UNIX_RANDOM_SEED = "GOLDEN")
load(":goldens/unix/runtime_library_search_directories.bzl", _UNIX_RUNTIME_LIBRARY_SEARCH_DIRECTORIES = "GOLDEN")
load(":goldens/unix/shared_flag.bzl", _UNIX_SHARED_FLAG = "GOLDEN")
load(":goldens/unix/sysroot.bzl", _UNIX_SYSROOT = "GOLDEN")
load(":goldens/windows/def_file_gnu.bzl", _WINDOWS_DEF_FILE_GNU = "GOLDEN")
load(":goldens/windows/libraries_to_link.bzl", _WINDOWS_LIBRARIES_TO_LINK = "GOLDEN")
load(":goldens/windows/thin_lto.bzl", _WINDOWS_THIN_LTO = "GOLDEN")

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

platform(
    name = "windows",
    constraint_values = [
        "@platforms//os:windows",
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
    name = "libraries_to_link_windows_test",
    actual_implementation = "//cc/toolchains/args/libraries_to_link",
    expected = _WINDOWS_LIBRARIES_TO_LINK,
    feature_name = "libraries_to_link_test",
    platform = ":windows",
)

compare_feature_implementation(
    name = "linker_param_file_test",
    actual_implementation = "//cc/toolchains/args/linker_param_file",
    expected = _UNIX_LINKER_PARAM_FILE,
    feature_name = "linker_param_file_test",
    platform = ":linux",
)

compare_feature_implementation(
    name = "def_file_test",
    actual_implementation = "//cc/toolchains/args/def_file:def_file_args",
    expected = _WINDOWS_DEF_FILE_GNU,
    platform = ":windows",
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

compare_cc_feature_implementation(
    name = "thin_lto_macos_test",
    actual_implementation = "//cc/toolchains/args/thin_lto:feature",
    expected = _MACOS_THIN_LTO,
    platform = ":macos",
)

compare_cc_feature_implementation(
    name = "thin_lto_windows_test",
    actual_implementation = "//cc/toolchains/args/thin_lto:feature",
    expected = _WINDOWS_THIN_LTO,
    platform = ":windows",
)

# The compile args C++20 module actions share. Bazel's CppActionConfigs.java
# predates those actions, so these goldens follow the legacy features in
# unix_cc_toolchain_config instead: module compiles and dependency scans get
# what preprocessing needs, and module codegen gets what code generation needs.

cc_sysroot(
    name = "sysroot",
    sysroot = "//tests/rule_based_toolchain/testdata:directory",
)

compare_cc_feature_implementation(
    name = "includes_unix_test",
    actual_implementation = "//cc/toolchains/args/include_flags:includes_feature",
    expected = _UNIX_INCLUDES,
    platform = ":linux",
)

compare_cc_feature_implementation(
    name = "include_paths_unix_test",
    actual_implementation = "//cc/toolchains/args/include_flags:include_paths_feature",
    expected = _UNIX_INCLUDE_PATHS,
    platform = ":linux",
)

compare_feature_implementation(
    name = "external_include_paths_unix_test",
    actual_implementation = "//cc/toolchains/args/external_include_paths",
    expected = _UNIX_EXTERNAL_INCLUDE_PATHS,
    feature_name = "external_include_paths_test",
    platform = ":linux",
)

compare_cc_feature_implementation(
    name = "preprocessor_defines_unix_test",
    actual_implementation = "//cc/toolchains/args/preprocessor_defines:feature",
    expected = _UNIX_PREPROCESSOR_DEFINES,
    platform = ":linux",
)

compare_cc_feature_implementation(
    name = "pic_unix_test",
    actual_implementation = "//cc/toolchains/args/pic_flags:pic_feature",
    expected = _UNIX_PIC,
    platform = ":linux",
)

compare_cc_feature_implementation(
    name = "random_seed_unix_test",
    actual_implementation = "//cc/toolchains/args/random_seed:feature",
    expected = _UNIX_RANDOM_SEED,
    platform = ":linux",
)

compare_cc_feature_implementation(
    name = "per_object_debug_info_unix_test",
    actual_implementation = "//cc/toolchains/args/fission_flags:per_object_debug_info_feature",
    expected = _UNIX_PER_OBJECT_DEBUG_INFO,
    platform = ":linux",
)

compare_cc_feature_implementation(
    name = "layering_check_unix_test",
    actual_implementation = "//cc/toolchains/args/layering_check",
    expected = _UNIX_LAYERING_CHECK,
    platform = ":linux",
)

compare_feature_implementation(
    name = "sysroot_unix_test",
    actual_implementation = ":sysroot",
    expected = _UNIX_SYSROOT,
    feature_name = "sysroot_test",
    platform = ":linux",
)
