"""Mock rules for testing C++ rules."""

load("//cc/common:cc_common.bzl", "cc_common")
load("//cc/common:cc_info.bzl", "CcInfo")

CcRuntimesInfo = provider(
    doc = "Information about runtime libraries to link into c++ targets.",
    fields = ["runtimes", "copts"],
)

def _cc_runtimes_toolchain_impl(ctx):
    return [platform_common.ToolchainInfo(
        cc_runtimes_info = CcRuntimesInfo(
            runtimes = ctx.attr.runtimes,
            copts = ctx.attr.copts,
        ),
    )]

cc_runtimes_toolchain = rule(
    implementation = _cc_runtimes_toolchain_impl,
    attrs = {
        "runtimes": attr.label_list(),
        "copts": attr.string_list(),
    },
)

def _declare_lib_file(ctx, extension = ".a"):
    parts = ctx.label.name.split("/")
    basename = parts[-1]
    dirname = "/".join(parts[:-1])
    if dirname:
        lib_name = dirname + "/lib" + basename + extension
    else:
        lib_name = "lib" + basename + extension
    return ctx.actions.declare_file(lib_name)

def _mock_runtime_library_impl(ctx):
    lib_file = _declare_lib_file(ctx)
    ctx.actions.write(output = lib_file, content = "mock archive content")
    library_to_link = cc_common.create_library_to_link(
        actions = ctx.actions,
        static_library = lib_file,
    )
    linker_input = cc_common.create_linker_input(
        libraries = depset([library_to_link]),
        owner = ctx.label,
    )
    linking_context = cc_common.create_linking_context(
        linker_inputs = depset([linker_input]),
    )
    return [
        CcInfo(linking_context = linking_context),
        DefaultInfo(files = depset([lib_file])),
    ]

mock_runtime_library = rule(
    implementation = _mock_runtime_library_impl,
    attrs = {},
)

def _mock_go_library_impl(ctx):
    lib_file = _declare_lib_file(ctx)
    ctx.actions.write(output = lib_file, content = "mock go archive")
    library_to_link = cc_common.create_library_to_link(
        actions = ctx.actions,
        static_library = lib_file,
    )
    linker_input = cc_common.create_linker_input(
        libraries = depset([library_to_link]),
        owner = ctx.label,
    )
    linking_context = cc_common.create_linking_context(
        linker_inputs = depset([linker_input]),
    )
    return [
        CcInfo(linking_context = linking_context),
        DefaultInfo(files = depset([lib_file])),
    ]

mock_go_library = rule(
    implementation = _mock_go_library_impl,
    attrs = {},
)
