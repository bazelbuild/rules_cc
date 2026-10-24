load("@platforms//host:constraints.bzl", "HOST_CONSTRAINTS")
load("@rules_cc//cc/toolchains:std_module_toolchain.bzl", "std_module_toolchain")

toolchain(
    name = "cc-toolchain-arm64_windows",
    exec_compatible_with = HOST_CONSTRAINTS,
    target_compatible_with = [
        "@platforms//cpu:arm64",
        "@platforms//os:windows",
    ],
    toolchain = "@local_config_cc//:cc-compiler-arm64_windows",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)

toolchain(
    name = "cc-toolchain-x64_windows",
    exec_compatible_with = HOST_CONSTRAINTS,
    target_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:windows",
    ],
    toolchain = "@local_config_cc//:cc-compiler-x64_windows",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)

toolchain(
    name = "cc-toolchain-armeabi-v7a",
    exec_compatible_with = HOST_CONSTRAINTS,
    target_compatible_with = [
        "@platforms//cpu:armv7",
        "@platforms//os:android",
    ],
    toolchain = "@local_config_cc//:cc-compiler-armeabi-v7a",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)

std_module_toolchain(
    name = "std-module-x64_windows",
    std_module = "@local_config_cc//:std",
)

toolchain(
    name = "std-module-toolchain-x64_windows",
    exec_compatible_with = HOST_CONSTRAINTS,
    target_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:windows",
    ],
    toolchain = ":std-module-x64_windows",
    toolchain_type = "@rules_cc//cc/toolchains:std_module_toolchain_type",
)
