"""Repository rules entry point module for rules_cc."""

# WARNING: This file only exists for backwards-compatibility.
# rules_cc uses the Bazel federation, so please add any new dependencies to
# rules_cc_deps() in
# https://github.com/bazelbuild/bazel-federation/blob/master/repositories.bzl
# Third party dependencies can be added to
# https://github.com/bazelbuild/bazel-federation/blob/master/third_party_repositories.bzl
# Ideally we'd delete this entire file.

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("//cc/private/toolchain:cc_configure.bzl", "cc_configure")

def rules_cc_dependencies():
    _maybe(
        http_archive,
        name = "bazel_skylib",
        sha256 = "710c2ca4b4d46250cdce2bf8f5aa76ea1f0cba514ab368f2988f70e864cfaf51",
        strip_prefix = "bazel-skylib-1.2.1",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/archive/1.2.1.tar.gz",
            "https://github.com/bazelbuild/bazel-skylib/archive/1.2.1.tar.gz",
        ],
    )

# buildifier: disable=unnamed-macro
def rules_cc_toolchains(*args):
    cc_configure(*args)

def _maybe(repo_rule, name, **kwargs):
    if not native.existing_rule(name):
        repo_rule(name = name, **kwargs)
