load("@bazel_features//:features.bzl", "bazel_features")
load("@rules_shell//shell:sh_library.bzl", "sh_library")
load("//cc:cc_test.bzl", "cc_test")

cc_test(
    name = "windows_param_file_test",
    srcs = ["windows_param_file_test.cc"],
    copts = ['-DGREETING="Hello world!"'],
    features = ["no_copts_tokenization"],
    local_defines = ["""'LOCAL_GREETING="Hello local world!"'"""],
    # Use a public feature introduced in Bazel 10 as the version gate.
    target_compatible_with = [] if bazel_features.rules.constraint_setting_has_refines_constraint_value else ["@platforms//:incompatible"],
)

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
