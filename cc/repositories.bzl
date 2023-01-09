"""Repository rules entry point module for rules_cc."""

def rules_cc_dependencies():
    pass

# buildifier: disable=unnamed-macro
def rules_cc_toolchains(*_args):
    # Use the auto-configured toolchains defined in @bazel_tools//tools/cpp until they have been
    # fully migrated to rules_cc.
    pass
