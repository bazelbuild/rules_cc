load("//cc/private/rules_impl:cc_binary_impl.bzl", "cc_binary_impl_wrapper")
load("//cc/private/rules_impl:cc_library_impl.bzl", "cc_library_impl_wrapper")
load("//cc/private/rules_impl:cc_shared_library_impl.bzl", "cc_shared_library_impl_wrapper")
load("//cc/private/rules_impl:cc_test_impl.bzl", "cc_test_impl_wrapper")

licenses(["notice"])

filegroup(
    name = "srcs",
    srcs = [
        "BUILD",
    ],
    visibility = ["//cc/private/rules_impl:__pkg__"],
)

cc_binary_impl_wrapper(
    name = "cc_binary_impl_wrapper",
    applicable_licenses = [],
    visibility = ["//visibility:public"],
)

cc_library_impl_wrapper(
    name = "cc_library_impl_wrapper",
    applicable_licenses = [],
    visibility = ["//visibility:public"],
)

cc_test_impl_wrapper(
    name = "cc_test_impl_wrapper",
    applicable_licenses = [],
    visibility = ["//visibility:public"],
)

cc_shared_library_impl_wrapper(
    name = "cc_shared_library_impl_wrapper",
    applicable_licenses = [],
    visibility = ["//visibility:public"],
)
