load("@rules_shell//shell:sh_library.bzl", "sh_library")

sh_library(
    name = "unittest_bash",
    testonly = True,
    srcs = ["unittest.bash"],
    visibility = ["//tests:__subpackages__"],
)

sh_library(
    name = "test_utils_sh",
    testonly = True,
    srcs = ["test_utils.sh"],
    visibility = ["//tests:__subpackages__"],
)
