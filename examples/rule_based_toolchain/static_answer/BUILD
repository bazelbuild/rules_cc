package(default_visibility = ["//visibility:public"])

licenses(["notice"])  # Apache 2.0

cc_library(
    name = "answer",
    includes = ["public"],
    hdrs = ["public/static_answer.h"],
    srcs = ["static_answer.cc"],
    linkstatic = True,
    visibility = ["//visibility:private"],
)

# TODO: This should be a cc_static_library when that's supported.
alias(
    name = "static_answer",
    actual = ":answer",
)
