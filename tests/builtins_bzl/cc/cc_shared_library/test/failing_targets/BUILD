load("//cc:cc_binary.bzl", "cc_binary")
load("//cc:cc_library.bzl", "cc_library")
load("//cc:cc_shared_library.bzl", "cc_shared_library")

licenses(["notice"])

package(default_visibility = ["//tests/builtins_bzl/cc/cc_shared_library:__subpackages__"])

TAGS = [
    "manual",
    "nobuilder",
    "notap",
]

cc_binary(
    name = "should_fail_binary",
    dynamic_deps = ["//tests/builtins_bzl/cc/cc_shared_library/test:bar_so"],
    tags = TAGS,
    deps = [
        "//tests/builtins_bzl/cc/cc_shared_library/test:barX",
    ],
)

cc_shared_library(
    name = "should_fail_shared_lib",
    dynamic_deps = ["//tests/builtins_bzl/cc/cc_shared_library/test:bar_so"],
    tags = TAGS,
    deps = [
        ":intermediate",
    ],
)

cc_library(
    name = "intermediate",
    deps = [
        "//tests/builtins_bzl/cc/cc_shared_library/test:barX",
    ],
)

cc_library(
    name = "a",
    srcs = ["a.cc"],
)

cc_library(
    name = "b",
    srcs = ["b.cc"],
)

cc_library(
    name = "c",
    srcs = ["c.cc"],
)

cc_shared_library(
    name = "two_dynamic_deps_same_export_in_so",
    dynamic_deps = [
        ":b_so",
        ":b2_so",
    ],
    tags = TAGS,
    deps = [
        ":a",
    ],
)

cc_binary(
    name = "two_dynamic_deps_same_export_in_binary",
    srcs = ["main.cc"],
    dynamic_deps = [
        ":b_so",
        ":b2_so",
    ],
    tags = TAGS,
)

cc_shared_library(
    name = "b_so",
    tags = TAGS,
    deps = [
        ":b",
    ],
)

cc_shared_library(
    name = "b2_so",
    tags = TAGS,
    deps = [
        ":b",
    ],
)

cc_shared_library(
    name = "failing_with_no_deps_so",
    tags = TAGS,
)

cc_shared_library(
    name = "failing_only_dynamic_lib",
    tags = TAGS,
    deps = [
        "dynamic_only",
    ],
)

cc_library(
    name = "dynamic_only",
    srcs = [
        "libabc.so",
    ],
)

genrule(
    name = "abc_lib",
    srcs = [],
    outs = ["libabc.so"],
    cmd = "touch \"$@\"",
)
