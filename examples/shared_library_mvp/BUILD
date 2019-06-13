load("//:cc_shared_library.bzl", "cc_bin", "cc_shared_library")

sh_binary(
    name = "symbol_grabber",
    srcs = ["symbol_grabber.sh"],
)

cc_bin(
    name = "main",
    srcs = ["main.cc"],
    dynamic_deps = [":libA_shared.so"],
)

# FIX: add cc_binary to test
cc_shared_library(
    name = "libA_shared.so",
    of = "A",
    dynamic_deps = [":libB_shared.so"],
)

cc_library(
    name = "A",
    srcs = ["a.cc"],
    hdrs = ["a.h"],
    deps = [
        "C",
        "D",
    ],
)

cc_shared_library(
    name = "libB_shared.so",
    of = "B",
    #dynamic_deps = [":libE_shared.so"],
)

cc_library(
    name = "B",
    srcs = ["b.cc"],
    hdrs = ["b.h"],
    deps = [
        "E",
        "F",
    ],
)

cc_library(
    name = "C",
    srcs = ["c.cc"],
    hdrs = ["c.h"],
    deps = [
        "E",
    ],
)

cc_library(
    name = "D",
    srcs = ["d.cc"],
    hdrs = ["d.h"],
    deps = [
        "B",
    ],
)

cc_shared_library(
    name = "libE_shared.so",
    of = "E",
)

cc_library(
    name = "E",
    srcs = ["e.cc"],
    hdrs = ["e.h"],
)

cc_library(
    name = "F",
    srcs = ["f.cc"],
    hdrs = ["f.h"],
)
