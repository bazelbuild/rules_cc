load("@bazel_binaries//:defs.bzl", "bazel_binaries")
load("@rules_bazel_integration_test//bazel_integration_test:defs.bzl", "default_test_runner")
load("@rules_bazel_integration_test//bazel_integration_test:defs.bzl", "bazel_integration_test")
load("@rules_shell//shell:sh_binary.bzl", "sh_binary")
load("@rules_shell//shell:sh_library.bzl", "sh_library")

sh_library(
    name = "test_utils",
    srcs = ["test_utils.sh"],
)

genrule(
    name = "no_rebuild_on_irrelevant_header_change_build_gen",
    srcs = ["no_rebuild_on_irrelevant_header_change/BUILD.test"],
    outs = ["no_rebuild_on_irrelevant_header_change/BUILD"],
    cmd = "cp $< $@",
)

filegroup(
    name = "no_rebuild_on_irrelevant_header_change_files",
    srcs = [
        ":no_rebuild_on_irrelevant_header_change/BUILD",
    ] + glob(["no_rebuild_on_irrelevant_header_change/**"])
)

sh_binary(
    name = "no_rebuild_on_irrelevant_header_change_test_runner",
    testonly = True,
    srcs = ["no_rebuild_on_irrelevant_header_change_test_runner.sh"],
    deps = [
        ":test_utils",
        "@rules_shell//shell/runfiles",
    ],
    data = [
        "@rules_bazel_integration_test//tools:create_scratch_dir",
    ],
)

bazel_integration_test(
    name = "no_rebuild_on_irrelevant_header_change_test",
    test_runner = ":no_rebuild_on_irrelevant_header_change_test_runner",
    bazel_binaries = bazel_binaries,
    bazel_version = "8.5.1",
    workspace_path = "no_rebuild_on_irrelevant_header_change",
    workspace_files = [
        ":no_rebuild_on_irrelevant_header_change_files",
        "//:all_files_for_testing",
    ],
    tags = [],
)
