"""Bzl load visibility package specs"""

# buildifier: disable=bzl-visibility
load("//cc/private:cc_internal.bzl", _cc_internal = "cc_internal")

visibility("//cc/...")

def check_private_api():
    _cc_internal.check_private_api(allowlist = PRIVATE_STARLARKIFICATION_ALLOWLIST, depth = 2)

def wrap_with_check_private_api(symbol):
    """
    Protects the symbol so it can only be used internally.

    Returns:
      A function. When the function is invoked (without any params), the check
      is done and if it passes the symbol is returned.
    """

    def callback():
        _cc_internal.check_private_api(allowlist = PRIVATE_STARLARKIFICATION_ALLOWLIST)
        return symbol

    return callback

# Things that are publicly visible in the open-source Bazel world, but have
# restricted visibility within Google's monorepo.
PUBLIC_IF_NOT_GOOGLE = ["public"]

PRIVATE_RULES_VISIBILITY_FOR_BZL = []

PRIVATE_RULES_VISIBILITY_FOR_BUILD = []

PRIVATE_RULES_ALLOWLIST = []

CREATE_COMPILE_ACTION_API_ALLOWLISTED_PACKAGES = []

PRIVATE_STARLARKIFICATION_ALLOWLIST = [
    ("_builtins", ""),
    # Android rules
    ("build_bazel_rules_android", ""),
    ("rules_android", ""),
    # Apple rules
    ("apple_support", ""),
    ("build_bazel_apple_support", ""),
    ("rules_apple", ""),
    ("build_bazel_rules_apple", ""),
    # C++ rules
    ("", "bazel_internal/test_rules/cc"),
    ("", "third_party/bazel_rules/rules_cc"),
    ("", "tools/build_defs/cc"),
    ("rules_cc", ""),
    # CUDA rules
    ("", "third_party/gpus/cuda"),
    # Go rules
    ("", "tools/build_defs/go"),
    # Java rules
    ("", "third_party/bazel_rules/rules_java"),
    ("rules_java", ""),
    # Objc rules
    ("", "tools/build_defs/objc"),
    # Protobuf rules
    ("", "third_party/protobuf"),
    ("protobuf", ""),
    ("com_google_protobuf", ""),
    ("", "third_party/upb"),
    # Rust rules
    ("", "third_party/bazel_rules/rules_rust/rust/private"),
    ("rules_rust", "rust/private"),
    ("rules_rs", "rust/private"),
    # Python rules
    ("", "third_party/bazel_rules/rules_python"),
    # Various
    ("", "research/colab"),
    ("", "javatests/com/google/devtools/grok/kythe"),
] + CREATE_COMPILE_ACTION_API_ALLOWLISTED_PACKAGES + PRIVATE_RULES_ALLOWLIST
