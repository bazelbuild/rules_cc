load("@bazel_skylib//rules:common_settings.bzl", "string_list_flag")
load("//cc:cc_library.bzl", "cc_library")
load("//cc/toolchains:cc_toolchain.bzl", "cc_toolchain")
load("//cc/toolchains:cc_toolchain_alias.bzl", "cc_toolchain_alias")
load(":additional_toolchains.bzl", "mock_additional_toolchains")
load(":cc_toolchain_config.bzl", "cc_toolchain_config")

package(default_visibility = ["//tests:__subpackages__"])

platform(
    name = "linux_x86_64",
    constraint_values = [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
    ],
)

platform(
    name = "macos_arm64",
    constraint_values = [
        "@platforms//os:macos",
        "@platforms//cpu:arm64",
    ],
)

toolchain_type(name = "toolchain_type")

toolchain_type(name = "test_runner_toolchain_type")

cc_toolchain_alias(name = "current_cc_toolchain")

# Sets the mock toolchain's available features. You can then use --features=foo to enable features.
# See features.bzl for values.
string_list_flag(
    name = "with_features",
    build_setting_default = [],
)

# Sets the mock toolchain's action configs.
string_list_flag(
    name = "with_action_configs",
    build_setting_default = [],
)

filegroup(
    name = "everything-multilib",
    srcs = glob(
        ["mock_version/**/*"],
        exclude_directories = 1,
    ),
    output_licenses = ["unencumbered"],
)

filegroup(
    name = "every-file",
    srcs = [
        "ar",
        "as",
        "compile",
        "dwp",
        "link",
        "llvm-profdata",
        "objcopy",
    ],
)

filegroup(
    name = "ar",
    srcs = [
        "ar-arm",
        "ar-armeabi-v7a",
        "ar-k8",
        "ar-piii",
    ],
)

filegroup(
    name = "ar-piii",
    srcs = [":everything-multilib"],
)

filegroup(
    name = "ar-k8",
    srcs = [":everything-multilib"],
)

filegroup(
    name = "ar-armeabi-v7a",
    srcs = [":everything-multilib"],
)

filegroup(
    name = "ar-arm",
    srcs = [":everything-multilib"],
)

filegroup(
    name = "as",
    srcs = [
        "as-arm",
        "as-armeabi-v7a",
        "as-k8",
        "as-piii",
    ],
)

filegroup(
    name = "as-piii",
    srcs = [":everything-multilib"],
)

filegroup(
    name = "as-k8",
    srcs = [":everything-multilib"],
)

filegroup(
    name = "as-armeabi-v7a",
    srcs = [":everything-multilib"],
)

filegroup(
    name = "as-arm",
    srcs = [":everything-multilib"],
)

filegroup(
    name = "compile",
    srcs = [
        "compile-arm",
        "compile-armeabi-v7a",
        "compile-k8",
        "compile-piii",
    ],
)

filegroup(
    name = "compile-piii",
    srcs = [":everything-multilib"],
)

filegroup(
    name = "compile-k8",
    srcs = [":everything-multilib"],
)

filegroup(
    name = "compile-armeabi-v7a",
    srcs = [":everything-multilib"],
)

filegroup(
    name = "compile-arm",
    srcs = [":everything-multilib"],
)

filegroup(
    name = "dwp",
    srcs = [
        "dwp-arm",
        "dwp-armeabi-v7a",
        "dwp-k8",
        "dwp-piii",
    ],
)

filegroup(
    name = "dwp-piii",
    srcs = [":everything-multilib"],
)

filegroup(
    name = "dwp-k8",
    srcs = [":everything-multilib"],
)

filegroup(
    name = "dwp-armeabi-v7a",
    srcs = [":everything-multilib"],
)

filegroup(
    name = "dwp-arm",
    srcs = [":everything-multilib"],
)

filegroup(
    name = "link",
    srcs = [
        "link-arm",
        "link-armeabi-v7a",
        "link-k8",
        "link-piii",
    ],
)

filegroup(
    name = "link-piii",
    srcs = [":everything-multilib"],
)

filegroup(
    name = "link-k8",
    srcs = [":everything-multilib"],
)

filegroup(
    name = "link-armeabi-v7a",
    srcs = [":everything-multilib"],
)

filegroup(
    name = "link-arm",
    srcs = [":everything-multilib"],
)

filegroup(
    name = "objcopy",
    srcs = [
        "objcopy-arm",
        "objcopy-armeabi-v7a",
        "objcopy-k8",
        "objcopy-piii",
    ],
)

filegroup(
    name = "objcopy-piii",
    srcs = [":everything-multilib"],
)

filegroup(
    name = "objcopy-k8",
    srcs = [":everything-multilib"],
)

filegroup(
    name = "objcopy-armeabi-v7a",
    srcs = [":everything-multilib"],
)

filegroup(
    name = "objcopy-arm",
    srcs = [":everything-multilib"],
)

filegroup(
    name = "llvm-profdata",
    srcs = [
        "llvm-profdata-arm",
        "llvm-profdata-armeabi-v7a",
        "llvm-profdata-k8",
        "llvm-profdata-piii",
    ],
)

filegroup(
    name = "llvm-profdata-piii",
    srcs = [":everything-multilib"],
)

filegroup(
    name = "llvm-profdata-k8",
    srcs = [":everything-multilib"],
)

filegroup(
    name = "llvm-profdata-armeabi-v7a",
    srcs = [":everything-multilib"],
)

filegroup(
    name = "llvm-profdata-arm",
    srcs = [":everything-multilib"],
)

toolchain(
    name = "cc-toolchain-k8-compiler",
    toolchain = ":cc-compiler-k8-compiler",
    toolchain_type = "//cc:toolchain_type",
)

mock_additional_toolchains()

cc_toolchain_config(
    name = "k8-compiler_config",
    abi_libc_version = "local",
    abi_version = "local",
    action_configs = [],
    artifact_name_patterns = {},
    builtin_sysroot = "/usr/grte/v1",
    cc_target_os = "",
    compiler = "compiler",
    cpu = "k8",
    cxx_builtin_include_directories = [],
    feature_names = [],
    host_system_name = "local",
    make_variables = {},
    target_libc = "local",
    target_system_name = "local",
    tool_paths = {},
)

toolchain(
    name = "cc-toolchain-macos-compiler",
    target_compatible_with = ["@platforms//os:macos"],
    toolchain = ":cc-compiler-macos-compiler",
    toolchain_type = "//cc:toolchain_type",
)

cc_toolchain_config(
    name = "macos-compiler_config",
    abi_libc_version = "local",
    abi_version = "local",
    action_configs = [],
    artifact_name_patterns = {},
    builtin_sysroot = "/usr/grte/v1",
    cc_target_os = "macos",
    compiler = "compiler",
    cpu = "darwin_arm64",
    cxx_builtin_include_directories = [],
    feature_names = [],
    host_system_name = "local",
    make_variables = {},
    target_libc = "macosx",  # NOTE: This value is read for legacy features
    target_system_name = "local",
    tool_paths = {},
)

cc_toolchain(
    name = "cc-compiler-macos-compiler",
    all_files = ":every-file",
    ar_files = "ar-k8",
    as_files = "as-k8",
    compiler_files = "compile-k8",
    coverage_files = "coverage-file",
    dwp_files = "dwp-k8",
    licenses = ["unencumbered"],
    linker_files = "link-k8",
    module_map = "crosstool.cppmap",
    objcopy_files = "objcopy-k8",
    output_licenses = ["unencumbered"],
    strip_files = ":every-file",
    supports_header_parsing = 1,
    toolchain_config = ":macos-compiler_config",
)

cc_toolchain(
    name = "cc-compiler-k8-compiler",
    all_files = ":every-file",
    ar_files = "ar-k8",
    as_files = "as-k8",
    compiler_files = "compile-k8",
    coverage_files = "coverage-file",
    dwp_files = "dwp-k8",
    licenses = ["unencumbered"],
    linker_files = "link-k8",
    module_map = "crosstool.cppmap",
    objcopy_files = "objcopy-k8",
    output_licenses = ["unencumbered"],
    strip_files = ":every-file",
    supports_header_parsing = 1,
    toolchain_config = ":k8-compiler_config",
)

filegroup(
    name = "interface_library_builder",
    srcs = ["build_interface_so"],
)

cc_library(
    name = "link_extra_lib",
    srcs = ["linkextra.cc"],
)

cc_library(name = "mock_malloc")

exports_files([
    "grep-includes",
    "link_dynamic_library",
])

filegroup(
    name = "aggregate-ddi",
    srcs = ["aggregate-ddi.sh"],
)

filegroup(
    name = "generate-modmap",
    srcs = ["generate-modmap.sh"],
)
