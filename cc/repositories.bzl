"""Repository rules entry point module for rules_cc."""

load("//cc/private/toolchain:cc_configure.bzl", "cc_configure")

def rules_cc_dependencies():
    # type: () -> None
    pass

# buildifier: disable=unnamed-macro
def rules_cc_toolchains():
    # type: () -> None
    cc_configure()
