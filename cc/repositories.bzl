"""Repository rules entry point module for rules_cc."""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

def rules_cc_dependencies():
    maybe(
        http_archive,
        name = "bazel_skylib",
        sha256 = "3b620033ca48fcd6f5ef2ac85e0f6ec5639605fa2f627968490e52fc91a9932f",
        strip_prefix = "bazel-skylib-1.3.0",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/archive/1.3.0.tar.gz",
            "https://github.com/bazelbuild/bazel-skylib/archive/1.3.0.tar.gz",
        ],
    )

# buildifier: disable=unnamed-macro
def rules_cc_toolchains(*_args):
    # Use the auto-configured toolchains defined in @bazel_tools//tools/cpp until they have been
    # fully migrated to rules_cc.
    pass
