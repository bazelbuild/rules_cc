"""Tests for static_import_strip_include_prefix."""

load("@bazel_features//:features.bzl", "bazel_features")
load("//cc:cc_import.bzl", "cc_import")
load("//cc:cc_test.bzl", "cc_test")

def static_import_strip_include_prefix_test(name):
    if not bazel_features.cc.cc_common_is_in_rules_cc:
        return

    cc_import(
        name = name + "_static_import_strip_include_prefix",
        hdrs = ["nested/stripped_bar.h"],
        static_library = ":static",
        strip_include_prefix = "nested",
    )

    cc_test(
        name = name,
        srcs = ["test_static_import_strip_include_prefix.cc"],
        deps = [":" + name + "_static_import_strip_include_prefix"],
    )
