load("//cc:cc_test.bzl", "cc_test")

licenses(["notice"])

cc_test(
    name = "runfiles_test",
    srcs = ["runfiles_test.cc"],
    deps = [
        "//cc/runfiles",
        "@googletest//:gtest_main",
    ],
)

cc_test(
    name = "runfiles_c_test",
    srcs = ["runfiles_c_test.cc"],
    deps = [
        "//cc/runfiles:runfiles_c",
        "@googletest//:gtest_main",
    ],
)

cc_test(
    name = "runfiles_c_pure_test",
    srcs = ["runfiles_c_test.c"],
    deps = ["//cc/runfiles:runfiles_c"],
)
