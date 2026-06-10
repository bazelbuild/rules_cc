"""Tests for local_includes."""

load("@bazel_features//:features.bzl", "bazel_features")
load("//cc:cc_import.bzl", "cc_import")
load("//cc:cc_test.bzl", "cc_test")

def define_test(name):
    if not bazel_features.cc.cc_common_is_in_rules_cc:
        return

    cc_import(
        name = name + "_lib_with_define",
        defines = ["IMPORT_DEFINE"],
        static_library = ":lib_only",
    )

    cc_test(
        name = name,
        srcs = ["require_define.cc"],
        deps = [":" + name + "_lib_with_define"],
    )
