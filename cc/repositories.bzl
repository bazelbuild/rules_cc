"""Repository rules entry point module for rules_cc."""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

def rules_cc_dependencies():
    maybe(
        http_archive,
        name = "bazel_skylib",
        sha256 = "9245b0549e88e356cd6a25bf79f97aa19332083890b7ac6481a2affb6ada9752",
        strip_prefix = "bazel-skylib-0.9.0",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/archive/0.9.0.tar.gz",
            "https://github.com/bazelbuild/bazel-skylib/archive/0.9.0.tar.gz",
        ],
    )

# buildifier: disable=unnamed-macro
def rules_cc_toolchains(*_args):
    # Use the auto-configured toolchains defined in @bazel_tools//tools/cpp until they have been
    # fully migrated to rules_cc.
    pass
