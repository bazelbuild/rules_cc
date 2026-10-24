"""Bootstrap rule for toolchain-provided C++ standard library modules."""

load("//cc:use_cc_toolchain.bzl", "use_cc_toolchain")
load("//cc/common:cc_info.bzl", "CcInfo")
load("//cc/common:semantics.bzl", "semantics")
load(":cc_library.bzl", "cc_library_attrs")
load("//cc/private/rules_impl:function_providing_rule.bzl", "proxy")

visibility("public")

# This intentionally omits semantics.get_std_module_toolchain(). It is used by
# the companion std-module toolchain and must not resolve that toolchain itself.
# Callers must put the "no_implicit_std_module" tag on the target, as the
# generated toolchain targets do: the bootstrap target provides the standard
# module itself and must not pick one up from the companion toolchain, which
# typically points back at this target.
cc_std_module_library = rule(
    implementation = proxy,
    attrs = cc_library_attrs,
    toolchains = use_cc_toolchain() + semantics.get_runtimes_toolchain(),
    fragments = ["cpp"] + semantics.additional_fragments(),
    provides = [CcInfo],
    exec_groups = {
        "cpp_link": exec_group(toolchains = use_cc_toolchain()),
    },
)
