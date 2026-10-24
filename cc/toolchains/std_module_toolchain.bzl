"""Toolchain provider for C++ standard library modules."""

load("//cc/common:cc_info.bzl", "CcInfo")

StdModuleToolchainInfo = provider(fields = ["std_module"])

def _impl(ctx):
    return [platform_common.ToolchainInfo(
        std_module_toolchain_info = StdModuleToolchainInfo(
            std_module = ctx.attr.std_module,
        ),
    )]

std_module_toolchain = rule(
    implementation = _impl,
    attrs = {
        "std_module": attr.label(
            mandatory = True,
            providers = [CcInfo],
        ),
    },
)
