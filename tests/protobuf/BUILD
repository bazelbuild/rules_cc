load("//cc:cc_library.bzl", "cc_library")
load("//cc:cc_test.bzl", "cc_test")
load("//cc:cc_shared_library.bzl", "cc_shared_library")
load("@com_google_protobuf//bazel:cc_proto_library.bzl", "cc_proto_library")
load("@com_google_protobuf//bazel:proto_library.bzl", "proto_library")

proto_library(
    name = "simple_pb",
    srcs = [
        "simple.proto",
    ],
)

cc_proto_library(
    name = "cc_simple_pb",
    deps = [
        ":simple_pb",
    ],
)

# An intermediate library that calls various generated Protobuf functions.
cc_library(
    name = "intermediate_proto_lib",
    srcs = [
        "intermediate_proto_lib.cc",
    ],
    hdrs = [
        "intermediate_proto_lib.h",
    ],
    deps = [
        ":cc_simple_pb",
    ],
)

# A shim that ensures the proto library is linked dynamically.
cc_shared_library(
    name = "dynamic_proto_lib",
    deps = [
        ":intermediate_proto_lib",
    ],
)

# A testable binary that ensures dynamic linking works as intended.
cc_test(
    name = "dynamic_proto_library_link_test",
    srcs = [
        "proto_library_link_test.cc",
    ],
    dynamic_deps = [
        ":dynamic_proto_lib",
    ],
    deps = [
        ":intermediate_proto_lib",
        "@googletest//:gtest_main",
    ],
)

# A testable binary that ensures the default link mode works as intended.
cc_test(
    name = "proto_library_link_test",
    srcs = [
        "proto_library_link_test.cc",
    ],
    deps = [
        ":intermediate_proto_lib",
        "@googletest//:gtest_main",
    ],
)
