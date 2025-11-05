# Copyright 2016 The Bazel Authors. All rights reserved.
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

# This becomes the BUILD file for @local_config_cc// under non-BSD unixes.

load("@rules_cc//cc:action_names.bzl", "ACTION_NAMES")
load("@rules_cc//cc/toolchains:cc_toolchain.bzl", "cc_toolchain")
load("@rules_cc//cc/toolchains:feature_legacy.bzl", "cc_feature_legacy", "cc_flag_group_legacy", "cc_flag_set_legacy")
load(":cc_toolchain_config.bzl", "cc_toolchain_config")

package(default_visibility = ["//visibility:public"])

licenses(["notice"])  # Apache 2.0

filegroup(
    name = "empty",
    srcs = [],
)

filegroup(
    name = "cc_wrapper",
    srcs = ["cc_wrapper.sh"],
)

filegroup(
    name = "validate_static_library",
    srcs = ["validate_static_library.sh"],
)

filegroup(
    name = "deps_scanner_wrapper",
    srcs = ["deps_scanner_wrapper.sh"],
)

filegroup(
    name = "compiler_deps",
    srcs = glob(
        ["extra_tools/**"],
        allow_empty = True,
    ) + [
        ":builtin_include_directory_paths",
        ":cc_wrapper",
        ":deps_scanner_wrapper",
        ":validate_static_library",
    ],
)

cc_flag_group_legacy(
    name = "foo_flag_group",
    flags = ["-foo"],
)

cc_flag_set_legacy(
    name = "foo_flag_set",
    actions = [
        ACTION_NAMES.cpp_compile,
        ACTION_NAMES.linkstamp_compile,
        ACTION_NAMES.cpp_header_parsing,
        ACTION_NAMES.cpp_module_compile,
        ACTION_NAMES.cpp_module_codegen,
        ACTION_NAMES.clif_match,
    ],
    flag_groups = [":foo_flag_group"],
)

cc_feature_legacy(
    name = "foo",
    flag_sets = [":foo_flag_set"],
)

toolchain(
    name = "my_linux_toolchain",
    exec_compatible_with = [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
    ],
    target_compatible_with = [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
    ],
    toolchain = ":cc-compiler-k8",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)

cc_toolchain(
    name = "cc-compiler-k8",
    all_files = ":compiler_deps",
    ar_files = ":compiler_deps",
    as_files = ":compiler_deps",
    compiler_files = ":compiler_deps",
    dwp_files = ":empty",
    linker_files = ":compiler_deps",
    module_map = None,
    objcopy_files = ":empty",
    strip_files = ":empty",
    supports_header_parsing = 1,
    supports_param_files = 1,
    toolchain_config = ":local",
    toolchain_identifier = "local",
)

cc_toolchain_config(
    name = "local",
    abi_libc_version = "local",
    abi_version = "local",
    compile_flags = [
        "-fstack-protector",
        "-Wall",
        "-Wunused-but-set-parameter",
        "-Wno-free-nonheap-object",
        "-fno-omit-frame-pointer",
    ],
    compiler = "gcc",
    conly_flags = [],
    coverage_compile_flags = ["--coverage"],
    coverage_link_flags = ["--coverage"],
    cpu = "k8",
    cxx_builtin_include_directories = [
        "/usr/lib/gcc/x86_64-linux-gnu/10/include",
        "/usr/local/include",
        "/usr/include/x86_64-linux-gnu",
        "/usr/include",
        "/usr/include/c++/10",
        "/usr/include/x86_64-linux-gnu/c++/10",
        "/usr/include/c++/10/backward",
    ],
    cxx_flags = ["-std=c++17"],
    dbg_compile_flags = ["-g"],
    extra_features = [":foo"],
    host_system_name = "local",
    link_flags = [
        "-fuse-ld=gold",
        "-B/usr/bin",
        "-Wl,-no-as-needed",
        "-Wl,-z,relro,-z,now",
        "-pass-exit-codes",
    ],
    link_libs = [
        "-Wl,--push-state,-as-needed",
        "-lstdc++",
        "-Wl,--pop-state",
        "-Wl,--push-state,-as-needed",
        "-lm",
        "-Wl,--pop-state",
    ],
    opt_compile_flags = [
        "-g0",
        "-O2",
        "-D_FORTIFY_SOURCE=1",
        "-DNDEBUG",
        "-ffunction-sections",
        "-fdata-sections",
    ],
    opt_link_flags = ["-Wl,--gc-sections"],
    supports_start_end_lib = True,
    target_libc = "local",
    target_system_name = "local",
    tool_paths = {
        "ar": "/usr/bin/ar",
        "ld": "/usr/bin/ld",
        "cpp": "/usr/bin/cpp-10",
        "gcc": "/usr/bin/gcc-10",
        "dwp": "/usr/bin/dwp",
        "gcov": "/usr/bin/gcov-10",
        "nm": "/usr/bin/nm",
        "objcopy": "/usr/bin/objcopy",
        "objdump": "/usr/bin/objdump",
        "strip": "/usr/bin/strip",
        "c++filt": "/usr/bin/c++filt",
        "cpp-module-deps-scanner": "deps_scanner_wrapper.sh",
        "parse_headers": "cc_wrapper.sh",
        "validate_static_library": "validate_static_library.sh",
    },
    toolchain_identifier = "local",
    unfiltered_compile_flags = [
        "-fno-canonical-system-headers",
        "-Wno-builtin-macro-redefined",
        "-D__DATE__=\"redacted\"",
        "-D__TIMESTAMP__=\"redacted\"",
        "-D__TIME__=\"redacted\"",
    ],
)
