"""Provides access to the actual rule function for extension

Only use these symbols for `inherit_attrs = ` in symbolic macros or as a parent
class for a rule.

DO NOT use these to define BUILD targets! For those, only the symbols from
@rules_cc//cc:<rule>.bzl are guaranteed to work as intended.
"""

load(
    "@cc_compatibility_proxy//:proxy.bzl",
    _cc_binary = "cc_binary",
    _cc_import = "cc_import",
    _cc_library = "cc_library",
    _cc_shared_library = "cc_shared_library",
    _cc_static_library = "cc_static_library",
    _cc_test = "cc_test",
    _objc_import = "objc_import",
    _objc_library = "objc_library",
)

cc_binary = _cc_binary
cc_import = _cc_import
cc_library = _cc_library
cc_shared_library = _cc_shared_library
cc_static_library = _cc_static_library
cc_test = _cc_test

objc_import = _objc_import
objc_library = _objc_library
