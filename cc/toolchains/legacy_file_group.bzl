"""Mapping of legacy file groups"""

# Taken from https://bazel.build/docs/cc-toolchain-config-reference#actions
# TODO: This is best-effort. Update this with the correct file groups once we
#  work out what actions correspond to what file groups.
LEGACY_FILE_GROUPS = {
    "ar_files": [
        Label("//cc/toolchains/actions:ar_actions"),
    ],
    "as_files": [
        Label("//cc/toolchains/actions:assembly_actions"),
    ],
    "compiler_files": [
        Label("//cc/toolchains/actions:cc_flags_make_variable"),
        Label("//cc/toolchains/actions:c_compile"),
        Label("//cc/toolchains/actions:cpp_compile"),
        Label("//cc/toolchains/actions:cpp_header_parsing"),
    ],
    # There are no actions listed for coverage and objcopy in action_names.bzl.
    "coverage_files": [],
    "dwp_files": [
        Label("//cc/toolchains/actions:dwp"),
    ],
    "linker_files": [
        Label("//cc/toolchains/actions:cpp_link_dynamic_library"),
        Label("//cc/toolchains/actions:cpp_link_nodeps_dynamic_library"),
        Label("//cc/toolchains/actions:cpp_link_executable"),
    ],
    "objcopy_files": [],
    "strip_files": [
        Label("//cc/toolchains/actions:strip"),
    ],
}
