"""Exposes some private APIs for tests"""

visibility(["//third_party/bazel_rules/rules_cc/..."])

def _cc_info_transitive_native_libraries(cc_info):
    if hasattr(cc_info, "_legacy_transitive_native_libraries"):
        return cc_info._legacy_transitive_native_libraries
    return cc_info.transitive_native_libraries()

def _cc_library_to_link_static_library(library_to_link):
    return library_to_link.static_library or library_to_link.pic_static_library

testutil = struct(
    cc_info_transitive_native_libraries = _cc_info_transitive_native_libraries,
    cc_library_to_link_static_library = _cc_library_to_link_static_library,
)
