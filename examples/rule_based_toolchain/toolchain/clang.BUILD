load("@rules_cc//cc/toolchains:tool.bzl", "cc_tool")
load("@rules_cc//cc/toolchains:tool_map.bzl", "cc_tool_map")
load("@bazel_skylib//rules/directory:directory.bzl", "directory")
load("@bazel_skylib//rules/directory:subdirectory.bzl", "subdirectory")
load("@bazel_skylib//lib:selects.bzl", "selects")

package(default_visibility = ["//visibility:public"])

licenses(["notice"])

# Directory-based rules in this toolchain only referece things in
# lib/ or include/ subdirectories.
directory(
    name = "toolchain_root",
    srcs = glob([
        "lib/**",
        "include/**",
    ]),
)

#####################
#       Tools       #
#####################

alias(
    name = "all_tools",
    actual = select({
        "@platforms//os:macos": ":macos_tools",
        "//conditions:default": ":default_tools",
    })
)

COMMON_TOOLS = {
    "@rules_cc//cc/toolchains/actions:assembly_actions": ":asm",
    "@rules_cc//cc/toolchains/actions:c_compile": ":clang",
    "@rules_cc//cc/toolchains/actions:cpp_compile_actions": ":clang++",
    "@rules_cc//cc/toolchains/actions:link_actions": ":lld",
    "@rules_cc//cc/toolchains/actions:objcopy_embed_data": ":llvm-objcopy",
    "@rules_cc//cc/toolchains/actions:strip": ":llvm-strip",
}

cc_tool_map(
    name = "default_tools",
    tools = COMMON_TOOLS | {
        "@rules_cc//cc/toolchains/actions:ar_actions": ":llvm-ar"
    },
    visibility = ["//visibility:private"],
)

cc_tool_map(
    name = "macos_tools",
    tools = COMMON_TOOLS | {
        "@rules_cc//cc/toolchains/actions:ar_actions": ":llvm-libtool-darwin"
    },
    visibility = ["//visibility:private"],
)

# TODO: https://github.com/bazelbuild/rules_cc/issues/235 - Workaround until
# Bazel has a more robust way to implement `cc_tool_map`.
alias(
    name = "asm",
    actual = ":clang",
)

cc_tool(
    name = "clang",
    src = select({
        "@platforms//os:windows": "//:bin/clang.exe",
        "//conditions:default": "//:bin/clang",
    }),
    data = glob([
        "bin/llvm",
        "include/**",
        "lib/clang/**/include/**",
    ]),
    allowlist_include_directories = [
        ":lib-clang-include",
    ],
)

cc_tool(
    name = "clang++",
    src = select({
        "@platforms//os:windows": "//:bin/clang++.exe",
        "//conditions:default": "//:bin/clang++",
    }),
    data = glob([
        "bin/llvm",
        "include/**",
        "lib/clang/**/include/**",
    ]),
    allowlist_include_directories = [
        ":include-x86_64-unknown-linux-gnu-c++-v1",
        ":include-c++-v1",
        ":lib-clang-include",
    ],
)

cc_tool(
    name = "lld",
    src = select({
        "@platforms//os:windows": "//:bin/clang++.exe",
        "//conditions:default": "//:bin/clang++",
    }),
    data = glob([
        "bin/llvm",
        "bin/lld*",
        "bin/ld*",
        "lib/**/*.a",
        "lib/**/*.so*",
        "lib/**/*.o",
    ]),
)

cc_tool(
    name = "llvm-ar",
    src = select({
        "@platforms//os:windows": "//:bin/llvm-ar.exe",
        "//conditions:default": "//:bin/llvm-ar",
    }),
    data = glob(["bin/llvm"]),
)

cc_tool(
    name = "llvm-libtool-darwin",
    src = select({
        "@platforms//os:windows": "//:bin/llvm-libtool-darwin.exe",
        "//conditions:default": "//:bin/llvm-libtool-darwin",
    }),
    data = glob(["bin/llvm"]),
)

cc_tool(
    name = "llvm-objcopy",
    src = select({
        "@platforms//os:windows": "//:bin/llvm-objcopy.exe",
        "//conditions:default": "//:bin/llvm-objcopy",
    }),
    data = glob(["bin/llvm"]),
)

cc_tool(
    name = "llvm-objdump",
    src = select({
        "@platforms//os:windows": "//:bin/llvm-objdump.exe",
        "//conditions:default": "//:bin/llvm-objdump",
    }),
    data = glob(["bin/llvm"]),
)

cc_tool(
    name = "llvm-cov",
    src = select({
        "@platforms//os:windows": "//:bin/llvm-cov.exe",
        "//conditions:default": "//:bin/llvm-cov",
    }),
    data = glob(["bin/llvm"]),
)

cc_tool(
    name = "llvm-strip",
    src = select({
        "@platforms//os:windows": "//:bin/llvm-strip.exe",
        "//conditions:default": "//:bin/llvm-strip",
    }),
    data = glob(["bin/llvm"]),
)

cc_tool(
    name = "clang-tidy",
    src = select({
        "@platforms//os:windows": "//:bin/clang-tidy.exe",
        "//conditions:default": "//:bin/clang-tidy",
    }),
    data = glob([
        "bin/llvm",
        "include/**",
        "lib/clang/**/include/**",
    ]) + select({
        "@platforms//os:linux": ["@linux_sysroot//:root"],
        "//conditions:default": [],
    }),
)

#####################
#     Arguments     #
#####################

# None...

#####################
#     Features      #
#####################

# None...

#####################
#     Builtins      #
#####################

subdirectory(
    name = "include-c++-v1",
    parent = ":toolchain_root",
    path = "include/c++/v1",
)

subdirectory(
    name = "lib-clang-include",
    parent = ":toolchain_root",
    path = "lib/clang/19/include",
)

subdirectory(
    name = "include-x86_64-unknown-linux-gnu-c++-v1",
    parent = ":toolchain_root",
    path = "include/x86_64-unknown-linux-gnu/c++/v1",
)
