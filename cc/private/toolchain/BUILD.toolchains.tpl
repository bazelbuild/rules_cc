load("@platforms//host:constraints.bzl", "HOST_CONSTRAINTS")

toolchain(
    name = "cc-toolchain-%{name}",
    exec_compatible_with = HOST_CONSTRAINTS,
    target_compatible_with = HOST_CONSTRAINTS,
    toolchain = "@local_config_cc//:cc-compiler-%{name}",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)
