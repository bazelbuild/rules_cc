load("//cc:defs.bzl", "cc_binary")
load("//examples:experimental_cc_shared_library.bzl", "cc_shared_library")

cc_shared_library(
    name = "baz_so",
    roots = ["//examples/test_cc_shared_library:a_suffix"],
     permissions = [
        "//examples/test_cc_shared_library:permissions",
    ],
)

cc_shared_library(
    name = "qux_so",
    dynamic_deps = [":baz_so"],
    roots = ["//examples/test_cc_shared_library:qux"],
    permissions = [
        "//examples/test_cc_shared_library:permissions",
    ],
)

cc_shared_library(
    name = "qux2_so",
    dynamic_deps = [":baz_so"],
    roots = ["//examples/test_cc_shared_library:qux2"],
    permissions = [
        "//examples/test_cc_shared_library:permissions",
    ],
)

cc_binary(
    name = "diamond_inheritance",
    srcs = ["main.cc"],
    dynamic_deps = [
        ":qux_so",
        ":qux2_so",
    ],
    deps = [
        "//examples/test_cc_shared_library:a_suffix"
    ]
)
