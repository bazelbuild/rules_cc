"""Repository rules entry point module for rules_cc."""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

def rules_cc_dependencies():
    maybe(
        http_archive,
        name = "bazel_skylib",
        sha256 = "2ea8a5ed2b448baf4a6855d3ce049c4c452a6470b1efd1504fdb7c1c134d220a",
        strip_prefix = "bazel-skylib-0.8.0",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/archive/0.8.0.tar.gz",
            "https://github.com/bazelbuild/bazel-skylib/archive/0.8.0.tar.gz",
        ],
    )

# buildifier: disable=unnamed-macro
def rules_cc_toolchains(*_args):
    # Use the auto-configured toolchains defined in @bazel_tools//tools/cpp until they have been
    # fully migrated to rules_cc.
    pass
