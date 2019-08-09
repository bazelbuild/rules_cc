# TODO(fweikert): Add setup.bzl file for skylib to the federation and load it instead of workspace.bzl
load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")
# TODO(fweikert): Also load rules_go's setup.bzl file from the federation once it exists
load("@io_bazel_rules_go//go:deps.bzl", "go_rules_dependencies", "go_register_toolchains")

def rules_cc_internal_setup():
    bazel_skylib_workspace()
    go_rules_dependencies()
    go_register_toolchains()
