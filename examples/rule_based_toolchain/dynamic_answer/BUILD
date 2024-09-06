package(default_visibility = ["//visibility:public"])

licenses(["notice"])  # Apache 2.0

cc_library(
    name = "headers",
    includes = ["public"],
    hdrs = ["public/dynamic_answer.h"],
    visibility = ["//visibility:private"],
)

cc_library(
    name = "answer",
    srcs = ["dynamic_answer.c"],
    deps = [":headers"],
    visibility = ["//visibility:private"],
)


cc_shared_library(
    name = "shared_library",
    deps = [":answer"],
    visibility = ["//visibility:private"],
)

# Forces linkage as a shared library.
cc_library(
    name = "dynamic_answer",
    deps = [":headers"],
    srcs = [":shared_library"],
)
