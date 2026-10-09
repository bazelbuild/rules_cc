load("@platforms//host:constraints.bzl", "HOST_CONSTRAINTS")
load("@rules_cc//cc/toolchains:std_module_toolchain.bzl", "std_module_toolchain")

toolchain(
    name = "cc-toolchain-%{name}",
    exec_compatible_with = HOST_CONSTRAINTS,
    target_compatible_with = HOST_CONSTRAINTS,
    toolchain = "@local_config_cc//:cc-compiler-%{name}",
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
    name = "std-module-%{name}",
    std_module = "@local_config_cc//:std",
)

toolchain(
    name = "std-module-toolchain-%{name}",
    exec_compatible_with = HOST_CONSTRAINTS,
    target_compatible_with = HOST_CONSTRAINTS,
    toolchain = ":std-module-%{name}",
    toolchain_type = "@rules_cc//cc/toolchains:std_module_toolchain_type",
)
