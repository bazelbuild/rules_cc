
# To build this directory with Bazel 0.24.1 you must pass the following
# argument:
#   --experimental_cc_skylark_api_enabled_packages=examples/my_c_rule

load("//cc:rules.bzl", "cc_binary")
load("//cc:rules.bzl", "cc_library")
load(":build_defs.bzl", "my_cc_library")

# Illustrate sandwich: our custom rule can depend on cc_library() and be
# depended on from cc_library().

cc_library(
    name = "foo",
    srcs = ["foo.c"],
    hdrs = ["foo.h"],
)

my_cc_library(
    name = "bar",
    srcs = ["bar.c"],
    hdrs = ["bar.h"],
    deps = [":foo"],
)

cc_library(
    name = "baz",
    srcs = ["baz.c"],
    hdrs = ["baz.h"],
    deps = [":bar"],
)

cc_binary(
    name = "main",
    srcs = ["main.c"],
    deps = [":baz"],
)
