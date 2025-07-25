# Copyright 2018 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This becomes the BUILD file for @local_config_cc// under Windows.

load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc/toolchains:cc_toolchain.bzl", "cc_toolchain")
load("@rules_cc//cc/toolchains:cc_toolchain_suite.bzl", "cc_toolchain_suite")
load(":windows_cc_toolchain_config.bzl", "cc_toolchain_config")
load(":armeabi_cc_toolchain_config.bzl", "armeabi_cc_toolchain_config")

package(default_visibility = ["//visibility:public"])

cc_library(name = "empty_lib")

# Label flag for extra libraries to be linked into every binary.
# TODO(bazel-team): Support passing flag multiple times to build a list.
label_flag(
    name = "link_extra_libs",
    build_setting_default = ":empty_lib",
)

# The final extra library to be linked into every binary target. This collects
# the above flag, but may also include more libraries depending on config.
cc_library(
    name = "link_extra_lib",
    deps = [
        ":link_extra_libs",
    ],
)

cc_library(
    name = "malloc",
)

filegroup(
    name = "empty",
    srcs = [],
)

filegroup(
    name = "mingw_compiler_files",
    srcs = [":builtin_include_directory_paths_mingw"]
)

filegroup(
    name = "clangcl_compiler_files",
    srcs = [":builtin_include_directory_paths_clangcl"]
)

filegroup(
    name = "msvc_compiler_files",
    srcs = [
        ":builtin_include_directory_paths_msvc",
        "%{msvc_deps_scanner_wrapper_path_x86}",
        "%{msvc_deps_scanner_wrapper_path_x64}",
        "%{msvc_deps_scanner_wrapper_path_arm}",
        "%{msvc_deps_scanner_wrapper_path_arm64}",
    ]
)

# Hardcoded toolchain, legacy behaviour.
cc_toolchain_suite(
    name = "toolchain",
    toolchains = {
        "armeabi-v7a|compiler": ":cc-compiler-armeabi-v7a",
        "x64_windows|msvc-cl": ":cc-compiler-x64_windows",
        "x64_x86_windows|msvc-cl": ":cc-compiler-x64_x86_windows",
        "x64_arm_windows|msvc-cl": ":cc-compiler-x64_arm_windows",
        "x64_arm64_windows|msvc-cl": ":cc-compiler-arm64_windows",
        "arm64_windows|msvc-cl": ":cc-compiler-arm64_windows",
        "x64_windows|msys-gcc": ":cc-compiler-x64_windows_msys",
        "x64_x86_windows|msys-gcc": ":cc-compiler-x64_x86_windows_msys",
        "x64_windows|mingw-gcc": ":cc-compiler-x64_windows_mingw",
        "x64_x86_windows|mingw-gcc": ":cc-compiler-x64_x86_windows_mingw",
        "x64_windows|clang-cl": ":cc-compiler-x64_windows-clang-cl",
        "x64_windows_msys": ":cc-compiler-x64_windows_msys",
        "x64_windows": ":cc-compiler-x64_windows",
        "x64_x86_windows": ":cc-compiler-x64_x86_windows",
        "x64_arm_windows": ":cc-compiler-x64_arm_windows",
        "x64_arm64_windows": ":cc-compiler-arm64_windows",
        "arm64_windows": ":cc-compiler-arm64_windows",
        "x64_arm64_windows|clang-cl": ":cc-compiler-arm64_windows-clang-cl",
        "arm64_windows|clang-cl": ":cc-compiler-arm64_windows-clang-cl",
        "armeabi-v7a": ":cc-compiler-armeabi-v7a",
    },
)

cc_toolchain(
    name = "cc-compiler-x64_windows_msys",
    toolchain_identifier = "msys_x64",
    toolchain_config = ":msys_x64",
    all_files = ":empty",
    ar_files = ":empty",
    as_files = ":mingw_compiler_files",
    compiler_files = ":mingw_compiler_files",
    dwp_files = ":empty",
    linker_files = ":empty",
    objcopy_files = ":empty",
    strip_files = ":empty",
    supports_param_files = 1,
)

cc_toolchain_config(
    name = "msys_x64",
    cpu = "x64_windows",
    compiler = "msys-gcc",
    host_system_name = "local",
    target_system_name = "local",
    target_libc = "msys",
    abi_version = "local",
    abi_libc_version = "local",
    cxx_builtin_include_directories = [%{cxx_builtin_include_directories}],
    tool_paths = {%{tool_paths}},
    tool_bin_path = "%{tool_bin_path}",
)

toolchain(
    name = "cc-toolchain-x64_windows_msys",
    exec_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:windows",
        "@rules_cc//cc/private/toolchain:msys",
    ],
    target_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:windows",
    ],
    toolchain = ":cc-compiler-x64_windows_msys",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)

cc_toolchain(
    name = "cc-compiler-x64_x86_windows_msys",
    toolchain_identifier = "msys_x64_x86",
    toolchain_config = ":msys_x64_x86",
    all_files = ":empty",
    ar_files = ":empty",
    as_files = ":mingw_compiler_files",
    compiler_files = ":mingw_compiler_files",
    dwp_files = ":empty",
    linker_files = ":empty",
    objcopy_files = ":empty",
    strip_files = ":empty",
    supports_param_files = 1,
)

cc_toolchain_config(
    name = "msys_x64_x86",
    cpu = "x64_x86_windows",
    compiler = "msys-gcc",
    host_system_name = "local",
    target_system_name = "local",
    target_libc = "msys",
    abi_version = "local",
    abi_libc_version = "local",
    cxx_builtin_include_directories = [%{cxx_builtin_include_directories}],
    tool_paths = {%{tool_paths}},
    tool_bin_path = "%{tool_bin_path}",
    default_compile_flags = ["-m32"],
    default_link_flags = ["-m32"],
)

toolchain(
    name = "cc-toolchain-x64_x86_windows_msys",
    exec_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:windows",
        "@rules_cc//cc/private/toolchain:msys",
    ],
    target_compatible_with = [
        "@platforms//cpu:x86_32",
        "@platforms//os:windows",
    ],
    toolchain = ":cc-compiler-x64_x86_windows_msys",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)

cc_toolchain(
    name = "cc-compiler-x64_windows_mingw",
    toolchain_identifier = "msys_x64_mingw",
    toolchain_config = ":msys_x64_mingw",
    all_files = ":empty",
    ar_files = ":empty",
    as_files = ":mingw_compiler_files",
    compiler_files = ":mingw_compiler_files",
    dwp_files = ":empty",
    linker_files = ":empty",
    objcopy_files = ":empty",
    strip_files = ":empty",
    supports_param_files = 0,
)

cc_toolchain_config(
    name = "msys_x64_mingw",
    cpu = "x64_windows",
    compiler = "mingw-gcc",
    host_system_name = "local",
    target_system_name = "local",
    target_libc = "mingw",
    abi_version = "local",
    abi_libc_version = "local",
    tool_bin_path = "%{mingw_tool_bin_path}",
    cxx_builtin_include_directories = [%{mingw_cxx_builtin_include_directories}],
    tool_paths = {%{mingw_tool_paths}},
)

toolchain(
    name = "cc-toolchain-x64_windows_mingw",
    exec_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:windows",
        "@rules_cc//cc/private/toolchain:mingw",
    ],
    target_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:windows",
    ],
    toolchain = ":cc-compiler-x64_windows_mingw",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)

cc_toolchain(
    name = "cc-compiler-x64_x86_windows_mingw",
    toolchain_identifier = "msys_x64_x86_mingw",
    toolchain_config = ":msys_x64_x86_mingw",
    all_files = ":empty",
    ar_files = ":empty",
    as_files = ":mingw_compiler_files",
    compiler_files = ":mingw_compiler_files",
    dwp_files = ":empty",
    linker_files = ":empty",
    objcopy_files = ":empty",
    strip_files = ":empty",
    supports_param_files = 0,
)

cc_toolchain_config(
    name = "msys_x64_x86_mingw",
    cpu = "x64_x86_windows",
    compiler = "mingw-gcc",
    host_system_name = "local",
    target_system_name = "local",
    target_libc = "mingw",
    abi_version = "local",
    abi_libc_version = "local",
    tool_bin_path = "%{mingw_tool_bin_path}",
    cxx_builtin_include_directories = [%{mingw_cxx_builtin_include_directories}],
    tool_paths = {%{mingw_tool_paths}},
    default_compile_flags = ["-m32"],
    default_link_flags = ["-m32"],
)

toolchain(
    name = "cc-toolchain-x64_x86_windows_mingw",
    exec_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:windows",
        "@rules_cc//cc/private/toolchain:mingw",
    ],
    target_compatible_with = [
        "@platforms//cpu:x86_32",
        "@platforms//os:windows",
    ],
    toolchain = ":cc-compiler-x64_x86_windows_mingw",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)

cc_toolchain(
    name = "cc-compiler-x64_windows",
    toolchain_identifier = "msvc_x64",
    toolchain_config = ":msvc_x64",
    all_files = ":empty",
    ar_files = ":empty",
    as_files = ":msvc_compiler_files",
    compiler_files = ":msvc_compiler_files",
    dwp_files = ":empty",
    linker_files = ":empty",
    objcopy_files = ":empty",
    strip_files = ":empty",
    supports_param_files = 1,
)

cc_toolchain_config(
    name = "msvc_x64",
    cpu = "x64_windows",
    compiler = "msvc-cl",
    host_system_name = "local",
    target_system_name = "local",
    target_libc = "msvcrt",
    abi_version = "local",
    abi_libc_version = "local",
    toolchain_identifier = "msvc_x64",
    msvc_env_tmp = "%{msvc_env_tmp_x64}",
    msvc_env_path = "%{msvc_env_path_x64}",
    msvc_env_include = "%{msvc_env_include_x64}",
    msvc_env_lib = "%{msvc_env_lib_x64}",
    msvc_cl_path = "%{msvc_cl_path_x64}",
    msvc_ml_path = "%{msvc_ml_path_x64}",
    msvc_link_path = "%{msvc_link_path_x64}",
    msvc_lib_path = "%{msvc_lib_path_x64}",
    cxx_builtin_include_directories = [%{msvc_cxx_builtin_include_directories_x64}],
    tool_paths = {
        "ar": "%{msvc_lib_path_x64}",
        "ml": "%{msvc_ml_path_x64}",
        "cpp": "%{msvc_cl_path_x64}",
        "gcc": "%{msvc_cl_path_x64}",
        "gcov": "wrapper/bin/msvc_nop.bat",
        "ld": "%{msvc_link_path_x64}",
        "nm": "wrapper/bin/msvc_nop.bat",
        "objcopy": "wrapper/bin/msvc_nop.bat",
        "objdump": "wrapper/bin/msvc_nop.bat",
        "strip": "wrapper/bin/msvc_nop.bat",
        "dumpbin": "%{msvc_dumpbin_path_x64}",
        "cpp-module-deps-scanner": "%{msvc_deps_scanner_wrapper_path_x64}",
    },
    archiver_flags = ["/MACHINE:X64"],
    default_link_flags = ["/MACHINE:X64"],
    dbg_mode_debug_flag = "%{dbg_mode_debug_flag_x64}",
    fastbuild_mode_debug_flag = "%{fastbuild_mode_debug_flag_x64}",
    supports_parse_showincludes = %{msvc_parse_showincludes_x64},
    shorten_virtual_includes = True,
)

toolchain(
    name = "cc-toolchain-x64_windows",
    exec_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:windows",
    ],
    target_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:windows",
    ],
    toolchain = ":cc-compiler-x64_windows",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)

cc_toolchain(
    name = "cc-compiler-x64_x86_windows",
    toolchain_identifier = "msvc_x64_x86",
    toolchain_config = ":msvc_x64_x86",
    all_files = ":empty",
    ar_files = ":empty",
    as_files = ":msvc_compiler_files",
    compiler_files = ":msvc_compiler_files",
    dwp_files = ":empty",
    linker_files = ":empty",
    objcopy_files = ":empty",
    strip_files = ":empty",
    supports_param_files = 1,
)

cc_toolchain_config(
    name = "msvc_x64_x86",
    cpu = "x64_windows",
    compiler = "msvc-cl",
    host_system_name = "local",
    target_system_name = "local",
    target_libc = "msvcrt",
    abi_version = "local",
    abi_libc_version = "local",
    toolchain_identifier = "msvc_x64_x86",
    msvc_env_tmp = "%{msvc_env_tmp_x86}",
    msvc_env_path = "%{msvc_env_path_x86}",
    msvc_env_include = "%{msvc_env_include_x86}",
    msvc_env_lib = "%{msvc_env_lib_x86}",
    msvc_cl_path = "%{msvc_cl_path_x86}",
    msvc_ml_path = "%{msvc_ml_path_x86}",
    msvc_link_path = "%{msvc_link_path_x86}",
    msvc_lib_path = "%{msvc_lib_path_x86}",
    cxx_builtin_include_directories = [%{msvc_cxx_builtin_include_directories_x86}],
    tool_paths = {
        "ar": "%{msvc_lib_path_x86}",
        "ml": "%{msvc_ml_path_x86}",
        "cpp": "%{msvc_cl_path_x86}",
        "gcc": "%{msvc_cl_path_x86}",
        "gcov": "wrapper/bin/msvc_nop.bat",
        "ld": "%{msvc_link_path_x86}",
        "nm": "wrapper/bin/msvc_nop.bat",
        "objcopy": "wrapper/bin/msvc_nop.bat",
        "objdump": "wrapper/bin/msvc_nop.bat",
        "strip": "wrapper/bin/msvc_nop.bat",
        "dumpbin": "%{msvc_dumpbin_path_x86}",
        "cpp-module-deps-scanner": "%{msvc_deps_scanner_wrapper_path_x86}",
    },
    archiver_flags = ["/MACHINE:X86"],
    default_link_flags = ["/MACHINE:X86"],
    dbg_mode_debug_flag = "%{dbg_mode_debug_flag_x86}",
    fastbuild_mode_debug_flag = "%{fastbuild_mode_debug_flag_x86}",
    supports_parse_showincludes = %{msvc_parse_showincludes_x86},
    shorten_virtual_includes = True,
)

toolchain(
    name = "cc-toolchain-x64_x86_windows",
    exec_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:windows",
    ],
    target_compatible_with = [
        "@platforms//cpu:x86_32",
        "@platforms//os:windows",
    ],
    toolchain = ":cc-compiler-x64_x86_windows",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)

cc_toolchain(
    name = "cc-compiler-x64_arm_windows",
    toolchain_identifier = "msvc_x64_arm",
    toolchain_config = ":msvc_x64_arm",
    all_files = ":empty",
    ar_files = ":empty",
    as_files = ":msvc_compiler_files",
    compiler_files = ":msvc_compiler_files",
    dwp_files = ":empty",
    linker_files = ":empty",
    objcopy_files = ":empty",
    strip_files = ":empty",
    supports_param_files = 1,
)

cc_toolchain_config(
    name = "msvc_x64_arm",
    cpu = "x64_windows",
    compiler = "msvc-cl",
    host_system_name = "local",
    target_system_name = "local",
    target_libc = "msvcrt",
    abi_version = "local",
    abi_libc_version = "local",
    toolchain_identifier = "msvc_x64_arm",
    msvc_env_tmp = "%{msvc_env_tmp_arm}",
    msvc_env_path = "%{msvc_env_path_arm}",
    msvc_env_include = "%{msvc_env_include_arm}",
    msvc_env_lib = "%{msvc_env_lib_arm}",
    msvc_cl_path = "%{msvc_cl_path_arm}",
    msvc_ml_path = "%{msvc_ml_path_arm}",
    msvc_link_path = "%{msvc_link_path_arm}",
    msvc_lib_path = "%{msvc_lib_path_arm}",
    cxx_builtin_include_directories = [%{msvc_cxx_builtin_include_directories_arm}],
    tool_paths = {
        "ar": "%{msvc_lib_path_arm}",
        "ml": "%{msvc_ml_path_arm}",
        "cpp": "%{msvc_cl_path_arm}",
        "gcc": "%{msvc_cl_path_arm}",
        "gcov": "wrapper/bin/msvc_nop.bat",
        "ld": "%{msvc_link_path_arm}",
        "nm": "wrapper/bin/msvc_nop.bat",
        "objcopy": "wrapper/bin/msvc_nop.bat",
        "objdump": "wrapper/bin/msvc_nop.bat",
        "strip": "wrapper/bin/msvc_nop.bat",
        "dumpbin": "%{msvc_dumpbin_path_arm}",
        "cpp-module-deps-scanner": "%{msvc_deps_scanner_wrapper_path_arm}",
    },
    archiver_flags = ["/MACHINE:ARM"],
    default_link_flags = ["/MACHINE:ARM"],
    dbg_mode_debug_flag = "%{dbg_mode_debug_flag_arm}",
    fastbuild_mode_debug_flag = "%{fastbuild_mode_debug_flag_arm}",
    supports_parse_showincludes = %{msvc_parse_showincludes_arm},
    shorten_virtual_includes = True,
)

toolchain(
    name = "cc-toolchain-x64_arm_windows",
    exec_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:windows",
    ],
    target_compatible_with = [
        "@platforms//cpu:arm",
        "@platforms//os:windows",
    ],
    toolchain = ":cc-compiler-x64_arm_windows",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)

cc_toolchain(
    name = "cc-compiler-arm64_windows",
    toolchain_identifier = "msvc_arm64",
    toolchain_config = ":msvc_arm64",
    all_files = ":empty",
    ar_files = ":empty",
    as_files = ":msvc_compiler_files",
    compiler_files = ":msvc_compiler_files",
    dwp_files = ":empty",
    linker_files = ":empty",
    objcopy_files = ":empty",
    strip_files = ":empty",
    supports_param_files = 1,
)

cc_toolchain_config(
    name = "msvc_arm64",
    cpu = "x64_windows",
    compiler = "msvc-cl",
    host_system_name = "local",
    target_system_name = "local",
    target_libc = "msvcrt",
    abi_version = "local",
    abi_libc_version = "local",
    toolchain_identifier = "msvc_arm64",
    msvc_env_tmp = "%{msvc_env_tmp_arm64}",
    msvc_env_path = "%{msvc_env_path_arm64}",
    msvc_env_include = "%{msvc_env_include_arm64}",
    msvc_env_lib = "%{msvc_env_lib_arm64}",
    msvc_cl_path = "%{msvc_cl_path_arm64}",
    msvc_ml_path = "%{msvc_ml_path_arm64}",
    msvc_link_path = "%{msvc_link_path_arm64}",
    msvc_lib_path = "%{msvc_lib_path_arm64}",
    cxx_builtin_include_directories = [%{msvc_cxx_builtin_include_directories_arm64}],
    tool_paths = {
        "ar": "%{msvc_lib_path_arm64}",
        "ml": "%{msvc_ml_path_arm64}",
        "cpp": "%{msvc_cl_path_arm64}",
        "gcc": "%{msvc_cl_path_arm64}",
        "gcov": "wrapper/bin/msvc_nop.bat",
        "ld": "%{msvc_link_path_arm64}",
        "nm": "wrapper/bin/msvc_nop.bat",
        "objcopy": "wrapper/bin/msvc_nop.bat",
        "objdump": "wrapper/bin/msvc_nop.bat",
        "strip": "wrapper/bin/msvc_nop.bat",
        "dumpbin": "%{msvc_dumpbin_path_arm64}",
        "cpp-module-deps-scanner": "%{msvc_deps_scanner_wrapper_path_arm64}",
    },
    archiver_flags = ["/MACHINE:ARM64"],
    default_link_flags = ["/MACHINE:ARM64"],
    dbg_mode_debug_flag = "%{dbg_mode_debug_flag_arm64}",
    fastbuild_mode_debug_flag = "%{fastbuild_mode_debug_flag_arm64}",
    supports_parse_showincludes = %{msvc_parse_showincludes_arm64},
    shorten_virtual_includes = True,
)

toolchain(
    name = "cc-toolchain-arm64_windows",
    exec_compatible_with = [
        "@platforms//os:windows",
    ],
    target_compatible_with = [
        "@platforms//cpu:arm64",
        "@platforms//os:windows",
    ],
    toolchain = ":cc-compiler-arm64_windows",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)


cc_toolchain(
    name = "cc-compiler-x64_windows-clang-cl",
    toolchain_identifier = "clang_cl_x64",
    toolchain_config = ":clang_cl_x64",
    all_files = ":empty",
    ar_files = ":empty",
    as_files = ":clangcl_compiler_files",
    compiler_files = ":clangcl_compiler_files",
    dwp_files = ":empty",
    linker_files = ":empty",
    objcopy_files = ":empty",
    strip_files = ":empty",
    supports_param_files = 1,
)

cc_toolchain_config(
    name = "clang_cl_x64",
    cpu = "x64_windows",
    compiler = "clang-cl",
    host_system_name = "local",
    target_system_name = "local",
    target_libc = "msvcrt",
    abi_version = "local",
    abi_libc_version = "local",
    toolchain_identifier = "clang_cl_x64",
    msvc_env_tmp = "%{clang_cl_env_tmp_x64}",
    msvc_env_path = "%{clang_cl_env_path_x64}",
    msvc_env_include = "%{clang_cl_env_include_x64}",
    msvc_env_lib = "%{clang_cl_env_lib_x64}",
    msvc_cl_path = "%{clang_cl_cl_path_x64}",
    msvc_ml_path = "%{clang_cl_ml_path_x64}",
    msvc_link_path = "%{clang_cl_link_path_x64}",
    msvc_lib_path = "%{clang_cl_lib_path_x64}",
    cxx_builtin_include_directories = [%{clang_cl_cxx_builtin_include_directories_x64}],
    tool_paths = {
        "ar": "%{clang_cl_lib_path_x64}",
        "ml": "%{clang_cl_ml_path_x64}",
        "cpp": "%{clang_cl_cl_path_x64}",
        "gcc": "%{clang_cl_cl_path_x64}",
        "gcov": "wrapper/bin/msvc_nop.bat",
        "ld": "%{clang_cl_link_path_x64}",
        "nm": "wrapper/bin/msvc_nop.bat",
        "objcopy": "wrapper/bin/msvc_nop.bat",
        "objdump": "wrapper/bin/msvc_nop.bat",
        "strip": "wrapper/bin/msvc_nop.bat",
    },
    archiver_flags = ["/MACHINE:X64"],
    default_link_flags = ["/MACHINE:X64"],
    dbg_mode_debug_flag = "%{clang_cl_dbg_mode_debug_flag_x64}",
    fastbuild_mode_debug_flag = "%{clang_cl_fastbuild_mode_debug_flag_x64}",
    supports_parse_showincludes = %{clang_cl_parse_showincludes_x64},
)

toolchain(
    name = "cc-toolchain-x64_windows-clang-cl",
    exec_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:windows",
        "@rules_cc//cc/private/toolchain:clang-cl",
    ],
    target_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:windows",
    ],
    toolchain = ":cc-compiler-x64_windows-clang-cl",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)

cc_toolchain(
    name = "cc-compiler-arm64_windows-clang-cl",
    toolchain_identifier = "clang_cl_arm64",
    toolchain_config = ":clang_cl_arm64",
    all_files = ":empty",
    ar_files = ":empty",
    as_files = ":clangcl_compiler_files",
    compiler_files = ":clangcl_compiler_files",
    dwp_files = ":empty",
    linker_files = ":empty",
    objcopy_files = ":empty",
    strip_files = ":empty",
    supports_param_files = 1,
)

cc_toolchain_config(
    name = "clang_cl_arm64",
    cpu = "arm64_windows",
    compiler = "clang-cl",
    host_system_name = "local",
    target_system_name = "aarch64-pc-windows-msvc",
    target_libc = "msvcrt",
    abi_version = "local",
    abi_libc_version = "local",
    toolchain_identifier = "clang_cl_arm64",
    msvc_env_tmp = "%{clang_cl_env_tmp_arm64}",
    msvc_env_path = "%{clang_cl_env_path_arm64}",
    msvc_env_include = "%{clang_cl_env_include_arm64}",
    msvc_env_lib = "%{clang_cl_env_lib_arm64}",
    msvc_cl_path = "%{clang_cl_cl_path_arm64}",
    msvc_ml_path = "%{clang_cl_ml_path_arm64}",
    msvc_link_path = "%{clang_cl_link_path_arm64}",
    msvc_lib_path = "%{clang_cl_lib_path_arm64}",
    cxx_builtin_include_directories = [%{clang_cl_cxx_builtin_include_directories_arm64}],
    tool_paths = {
        "ar": "%{clang_cl_lib_path_arm64}",
        "ml": "%{clang_cl_ml_path_arm64}",
        "cpp": "%{clang_cl_cl_path_arm64}",
        "gcc": "%{clang_cl_cl_path_arm64}",
        "gcov": "wrapper/bin/msvc_nop.bat",
        "ld": "%{clang_cl_link_path_arm64}",
        "nm": "wrapper/bin/msvc_nop.bat",
        "objcopy": "wrapper/bin/msvc_nop.bat",
        "objdump": "wrapper/bin/msvc_nop.bat",
        "strip": "wrapper/bin/msvc_nop.bat",
    },
    archiver_flags = ["/MACHINE:ARM64"],
    default_link_flags = ["/MACHINE:ARM64"],
    dbg_mode_debug_flag = "%{clang_cl_dbg_mode_debug_flag_arm64}",
    fastbuild_mode_debug_flag = "%{clang_cl_fastbuild_mode_debug_flag_arm64}",
    supports_parse_showincludes = %{clang_cl_parse_showincludes_arm64},
)

toolchain(
    name = "cc-toolchain-arm64_windows-clang-cl",
    exec_compatible_with = [
        "@platforms//os:windows",
        "@rules_cc//cc/private/toolchain:clang-cl",
    ],
    target_compatible_with = [
        "@platforms//cpu:arm64",
        "@platforms//os:windows",
    ],
    toolchain = ":cc-compiler-arm64_windows-clang-cl",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)

cc_toolchain(
    name = "cc-compiler-armeabi-v7a",
    toolchain_identifier = "stub_armeabi-v7a",
    toolchain_config = ":stub_armeabi-v7a",
    all_files = ":empty",
    ar_files = ":empty",
    as_files = ":empty",
    compiler_files = ":empty",
    dwp_files = ":empty",
    linker_files = ":empty",
    objcopy_files = ":empty",
    strip_files = ":empty",
    supports_param_files = 1,
)

armeabi_cc_toolchain_config(name = "stub_armeabi-v7a")

toolchain(
    name = "cc-toolchain-armeabi-v7a",
    exec_compatible_with = [
    ],
    target_compatible_with = [
        "@platforms//cpu:armv7",
        "@platforms//os:android",
    ],
    toolchain = ":cc-compiler-armeabi-v7a",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)
