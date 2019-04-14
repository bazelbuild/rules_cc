
load("//cc:api.bzl", "cc_library_func")

def _files_from_labels(labels):
    files = []
    for label in labels:
        files += list(label.files)
    return files

def _my_cc_library_impl(ctx):
    cc_info = cc_library_func(
        ctx = ctx,
        name = ctx.attr.name,
        srcs = _files_from_labels(ctx.attr.srcs),
        hdrs = _files_from_labels(ctx.attr.hdrs),
        deps = ctx.attr.deps,
    )

    return [
        # Allows rules that depend on us to link against our code.
        cc_info,

        # Make a "bazel build" of a my_cc_library() build the .a file as the
        # default output.  This is handy for inspecting the output.
        DefaultInfo(
            files = depset(
                [cc_info.linking_context.libraries_to_link[0].static_library],
            ),
        ),
    ]

my_cc_library = rule(
    implementation = _my_cc_library_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True),
        "hdrs": attr.label_list(allow_files = True),
        "deps": attr.label_list(),
        "_cc_toolchain": attr.label(default = "@bazel_tools//tools/cpp:current_cc_toolchain"),
    },
)
