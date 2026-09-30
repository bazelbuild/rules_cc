load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

package(default_visibility = ["//visibility:public"])

licenses(["notice"])  # Apache 2.0

filegroup(
    name = "bzl_srcs",
    srcs = glob(["**/*.bzl"]) + [
        "//cc/private/rules_impl/fdo:bzl_srcs",
    ],
)

filegroup(
    name = "srcs",
    srcs = glob([
        "**/*.bzl",
        "**/BUILD",
    ]) + [
        "//cc/private/rules_impl/fdo:srcs",
        "//cc/private/rules_impl/wrappers:srcs",
    ],
)

alias(
    name = "cc_flags_supplier_lib_bzl",
    actual = ":cc_flags_supplier_lib",
    deprecation = "Use //cc/private/rules_impl:cc_flags_supplier_lib instead.",
)

bzl_library(
    name = "cc_flags_supplier_lib",
    srcs = ["cc_flags_supplier_lib.bzl"],
    deps = ["//cc/common:cc_common"],
)

alias(
    name = "failing_cc_proto_library_bzl",
    actual = ":failing_cc_proto_library",
    deprecation = "Use //cc/private/rules_impl:failing_cc_proto_library instead.",
)

bzl_library(
    name = "failing_cc_proto_library",
    srcs = ["failing_cc_proto_library.bzl"],
    deps = ["//cc/common:cc_info"],
)

bzl_library(
    name = "core_rules",
    deprecation = "Use the individual bzl_library targets instead of this one.",
    deps = [
        ":attrs",
        ":cc_binary",
        ":cc_binary_impl",
        ":cc_import",
        ":cc_library",
        ":cc_library_impl",
        ":cc_shared_library",
        ":cc_shared_library_impl",
        ":cc_static_library",
        ":cc_test",
        ":cc_test_impl",
        ":objc_import",
        ":objc_library",
    ],
)

bzl_library(
    name = "toolchain_rules",
    deprecation = "Use the individual bzl_library targets instead of this one.",
    deps = [
        ":cc_toolchain",
        ":cc_toolchain_alias",
        ":cc_toolchain_info",
        ":cc_toolchain_provider_helper",
    ],
)

bzl_library(
    name = "objc_common",
    srcs = ["objc_common.bzl"],
    deps = [
        ":objc_compilation_context_info",
        "//cc/common:cc_common",
        "//cc/common:cc_info",
        "//cc/common:objc_info",
    ],
)

alias(
    name = "objc_compilation_support_bzl",
    actual = ":objc_compilation_support",
    deprecation = "Use //cc/private/rules_impl:objc_compilation_support instead.",
)

bzl_library(
    name = "objc_compilation_support",
    srcs = ["objc_compilation_support.bzl"],
    deps = [
        ":objc_common",
        ":objc_compilation_artifacts_info",
        ":objc_intermediate_artifacts",
        "//cc:build_settings",
        "//cc/common:cc_common",
        "//cc/common:cc_helper",
        "//cc/common:feature_names",
        "@bazel_skylib//lib:paths",
    ],
)

alias(
    name = "native_cc_common_bzl",
    actual = ":native_cc_common",
    deprecation = "Use //cc/private/rules_impl:native_cc_common instead.",
)

alias(
    name = "native_providers_bzl",
    actual = ":native_providers",
    deprecation = "Use //cc/private/rules_impl:native_providers instead.",
)

alias(
    name = "cc_toolchain_info_bzl",
    actual = ":cc_toolchain_info",
    deprecation = "Use //cc/private/rules_impl:cc_toolchain_info instead.",
)

bzl_library(
    name = "cc_toolchain_info",
    srcs = ["cc_toolchain_info.bzl"],
    deps = ["//cc/common:feature_names"],
)

alias(
    name = "function_providing_rule_bzl",
    actual = ":function_providing_rule",
    deprecation = "Use //cc/private/rules_impl:function_providing_rule instead.",
)

bzl_library(
    name = "attrs",
    srcs = ["attrs.bzl"],
    deps = [
        ":cc_shared_library",
        "//cc:cc_postmark_initializers",
        "//cc/common:cc_info",
        "//cc/common:semantics",
    ],
)

bzl_library(
    name = "cc_binary",
    srcs = ["cc_binary.bzl"],
    deps = [
        ":attrs",
        ":cc_shared_library",
        ":function_providing_rule",
        "//cc:cc_postmark_initializers",
        "//cc:use_cc_toolchain",
        "//cc/common:cc_info",
        "//cc/common:semantics",
    ],
)

bzl_library(
    name = "cc_binary_impl",
    srcs = ["cc_binary_impl.bzl"],
    deps = [
        ":cc_shared_library_impl",
        ":function_providing_rule",
        "//cc:cc_postmark",
        "//cc:find_cc_toolchain",
        "//cc/common:cc_common",
        "//cc/common:cc_debug_helper",
        "//cc/common:cc_helper",
        "//cc/common:cc_info",
        "//cc/common:debug_package_info",
        "//cc/common:feature_names",
        "//cc/common:semantics",
        "//cc/private:graph_node_info",
    ],
)

bzl_library(
    name = "cc_import",
    srcs = ["cc_import.bzl"],
    deps = [
        "//cc:find_cc_toolchain",
        "//cc/common:cc_common",
        "//cc/common:cc_helper",
        "//cc/common:cc_info",
        "//cc/common:feature_names",
        "//cc/common:semantics",
    ],
)

bzl_library(
    name = "cc_library",
    srcs = ["cc_library.bzl"],
    deps = [
        ":attrs",
        ":function_providing_rule",
        "//cc:use_cc_toolchain",
        "//cc/common:cc_info",
        "//cc/common:semantics",
    ],
)

bzl_library(
    name = "cc_library_impl",
    srcs = ["cc_library_impl.bzl"],
    deps = [
        ":function_providing_rule",
        "//cc:find_cc_toolchain",
        "//cc/common:cc_common",
        "//cc/common:cc_helper",
        "//cc/common:cc_info",
        "//cc/common:feature_names",
        "//cc/common:semantics",
    ],
)

bzl_library(
    name = "cc_shared_library",
    srcs = ["cc_shared_library.bzl"],
    deps = [
        ":function_providing_rule",
        "//cc:use_cc_toolchain",
        "//cc/common:cc_info",
        "//cc/common:cc_shared_library_hint_info",
        "//cc/common:cc_shared_library_info",
        "//cc/common:semantics",
        "//cc/private:graph_node_info",
        "@com_google_protobuf//bazel/common:proto_info_bzl",
    ],
)

bzl_library(
    name = "cc_shared_library_impl",
    srcs = ["cc_shared_library_impl.bzl"],
    deps = [
        ":function_providing_rule",
        "//cc:find_cc_toolchain",
        "//cc/common:cc_common",
        "//cc/common:cc_helper",
        "//cc/common:cc_info",
        "//cc/common:cc_shared_library_info",
        "//cc/common:feature_names",
        "//cc/common:semantics",
        "//cc/private:graph_node_info",
        "@bazel_skylib//lib:paths",
    ],
)

bzl_library(
    name = "cc_static_library",
    srcs = ["cc_static_library.bzl"],
    deps = [
        "//cc:action_names",
        "//cc:find_cc_toolchain",
        "//cc/common:cc_common",
        "//cc/common:cc_helper",
        "//cc/common:cc_info",
        "//cc/common:feature_names",
        "@bazel_skylib//lib:paths",
    ],
)

bzl_library(
    name = "cc_test",
    srcs = ["cc_test.bzl"],  # keep
    deps = [
        ":attrs",
        ":cc_shared_library",
        ":function_providing_rule",
        "//cc:cc_postmark_initializers",
        "//cc:use_cc_toolchain",
        "//cc/common:cc_info",
        "//cc/common:semantics",
    ],
)

bzl_library(
    name = "cc_test_impl",
    srcs = ["cc_test_impl.bzl"],
    deps = [
        ":cc_binary_impl",
        ":function_providing_rule",
        "//cc/common:cc_helper",
        "//cc/common:semantics",
    ],
)

bzl_library(
    name = "cc_toolchain",
    srcs = ["cc_toolchain.bzl"],
    deps = [
        ":cc_toolchain_provider_helper",
        "//cc/common:cc_common",
        "//cc/common:cc_helper",
        "//cc/common:semantics",
        "//cc/private/rules_impl/fdo:fdo_context",
        "//cc/toolchains:cc_toolchain_config_info",
        "//cc/toolchains:cc_toolchain_info",
        "//cc/toolchains:legacy_file_group",
        "//cc/toolchains/impl:collect",
        "//cc/toolchains/impl:toolchain_config",
    ],
)

bzl_library(
    name = "cc_toolchain_alias",
    srcs = ["cc_toolchain_alias.bzl"],
    deps = [
        "//cc:find_cc_toolchain",
        "//cc/common:cc_common",
        "//cc/common:cc_helper",
        "//cc/common:semantics",
    ],
)

bzl_library(
    name = "cc_toolchain_provider_helper",
    srcs = ["cc_toolchain_provider_helper.bzl"],
    deps = [
        ":cc_toolchain_info",
        "//cc:action_names",
        "//cc/common:cc_common",
        "//cc/common:cc_helper",
        "//cc/common:cc_helper_internal",
        "//cc/common:cc_info",
        "//cc/private/rules_impl/fdo:fdo_context",
        "@bazel_skylib//lib:paths",
    ],
)

bzl_library(
    name = "objc_attrs",
    srcs = ["objc_attrs.bzl"],
    deps = [
        ":objc_semantics",
        "//cc/common:cc_info",
    ],
)

bzl_library(
    name = "objc_import",
    srcs = ["objc_import.bzl"],
    deps = [
        ":objc_attrs",
        ":objc_compilation_support",
        "//cc:build_settings",
        "//cc:find_cc_toolchain",
        "//cc/common:cc_common",
        "//cc/common:cc_info",
        "//cc/common:semantics",
    ],
)

bzl_library(
    name = "objc_intermediate_artifacts",
    srcs = ["objc_intermediate_artifacts.bzl"],
    deps = [
        "//cc:build_settings",
        "//cc/common:cc_common",
        "@bazel_skylib//lib:paths",
    ],
)

bzl_library(
    name = "objc_library",
    srcs = ["objc_library.bzl"],
    deps = [
        ":objc_attrs",
        ":objc_common",
        ":objc_compilation_support",
        ":objc_semantics",
        "//cc:build_settings",
        "//cc:find_cc_toolchain",
        "//cc/common:cc_common",
        "//cc/common:cc_helper",
        "//cc/common:cc_info",
        "//cc/common:semantics",
    ],
)

bzl_library(
    name = "objc_semantics",
    srcs = ["objc_semantics.bzl"],
    deps = ["//cc/common:cc_common"],
)

bzl_library(
    name = "function_providing_rule",
    srcs = ["function_providing_rule.bzl"],
)

bzl_library(
    name = "native_cc_common",
    srcs = ["native_cc_common.bzl"],
)

bzl_library(
    name = "native_providers",
    srcs = ["native_providers.bzl"],
)

bzl_library(
    name = "objc_compilation_artifacts_info",
    srcs = ["objc_compilation_artifacts_info.bzl"],
)

bzl_library(
    name = "objc_compilation_context_info",
    srcs = ["objc_compilation_context_info.bzl"],
)
