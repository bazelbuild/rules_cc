"""Tests for local_includes."""

load("@bazel_features//:features.bzl", "bazel_features")
load("//cc:cc_library.bzl", "cc_library")
load("//cc:cc_test.bzl", "cc_test")

def local_includes_test(name):
    if not bazel_features.cc.cc_common_is_in_rules_cc:
        return

    cc_library(
        name = name + "_lib",
        srcs = [
            "lib/lib.c",
            "lib/private/private.c",
            "lib/private/private.h",
        ],
        hdrs = ["lib/include/public.h"],
        includes = [
            "lib/include",
        ],
        local_includes = [
            "lib/private",
        ],
    )

    cc_test(
        name = name,
        srcs = [
            "binary.c",
            "binary_helper.c",
            "private/binary_helper.h",
        ],
        local_includes = [
            "private",
        ],
        deps = [":" + name + "_lib"],
    )
