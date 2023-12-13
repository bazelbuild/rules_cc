"""Repository rules entry point module for rules_cc."""

load("@bazel_tools//tools/cpp:cc_configure.bzl", "cc_configure")

def rules_cc_dependencies():
    pass

# buildifier: disable=unnamed-macro
def rules_cc_toolchains(*args):
    cc_configure(*args)
