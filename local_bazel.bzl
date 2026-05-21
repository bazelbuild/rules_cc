def _local_bazel_import_impl(repository_ctx):
    if "windows" in repository_ctx.os.name.lower():
        bazel_real = "bazel-real.exe"
        bazel_name = "bazel.exe"
    else:
        bazel_real = "bazel-real"
        bazel_name = "bazel"

    # Prioritise bazel-real if it exists since it's much more likely to be an actual executable.
    bazel_path = repository_ctx.which(bazel_real)
    if bazel_path == None:
        bazel_path = repository_ctx.which(bazel_name)
        if bazel_path == None:
            fail("Neither '%s' or '%s' not found on PATH." % (bazel_real, bazel_name))

    repository_ctx.symlink(bazel_path, bazel_real)
    repository_ctx.file(
        "BUILD",
        executable = False,
        content =  """
load({sh_binary_bzl}, "sh_binary")

sh_binary(
    name = "{bazel_bin}",
    srcs = ["{bazel_binary}"],
    visibility = ["//visibility:public"],
)

alias(
    name = "bazel_bin",
    actual = "{bazel_bin}",
    visibility = ["//visibility:public"],
)
    """.format(
            sh_binary_bzl = repr(str(Label("@rules_shell//shell:sh_binary.bzl"))),
            bazel_bin = bazel_name,
            bazel_binary = bazel_real,
        ),
    )

local_bazel_import = repository_rule(
    implementation = _local_bazel_import_impl,
    environ = ["PATH"],
)
