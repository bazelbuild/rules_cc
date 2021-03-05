load("//cc:defs.bzl", "cc_binary", "cc_library")
load("//examples:experimental_cc_shared_library.bzl", "cc_shared_library", "cc_shared_library_permissions")

package(
    default_visibility = ["//examples/test_cc_shared_library:__pkg__"],
)

TAGS = [
    "manual",
    "nobuilder",
]

cc_binary(
    name = "should_fail_binary",
    dynamic_deps = ["//examples/test_cc_shared_library:foo_so"],
    tags = TAGS,
    deps = [
        "//examples/test_cc_shared_library:foo",
        "//examples/test_cc_shared_library:qux",
    ],
)

cc_shared_library(
    name = "permissions_fail_so",
    roots = [
        "//examples/test_cc_shared_library3:bar",
    ],
    tags = TAGS,
)

cc_shared_library_permissions(
    name = "permissions_fail",
    tags = TAGS,
    targets = [
        "//examples/test_cc_shared_library:foo",
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
    roots = [
        ":a",
    ],
    tags = TAGS,
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
    roots = [
        ":b",
    ],
    tags = TAGS,
)

cc_shared_library(
    name = "b2_so",
    roots = [
        ":b",
    ],
    tags = TAGS,
)
