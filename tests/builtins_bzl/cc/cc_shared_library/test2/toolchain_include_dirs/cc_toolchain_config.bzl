"""A minimal cc_toolchain_config rule for testing cxx_builtin_include_directories."""

load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/toolchains:cc_toolchain_config_info.bzl", "CcToolchainConfigInfo")

def _impl(ctx):
    return cc_common.create_cc_toolchain_config_info(
        ctx = ctx,
        toolchain_identifier = "test-toolchain",
        compiler = "test-compiler",
        target_system_name = "local",
        target_cpu = "k8",
        target_libc = "unknown",
        cxx_builtin_include_directories = ctx.attr.cxx_builtin_include_directories,
    )

cc_toolchain_config = rule(
    implementation = _impl,
    attrs = {
        "cxx_builtin_include_directories": attr.string_list(),
    },
    provides = [CcToolchainConfigInfo],
)
