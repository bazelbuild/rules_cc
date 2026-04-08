load("@bazel_binaries//:defs.bzl", "bazel_binaries")
load("@rules_bazel_integration_test//bazel_integration_test:defs.bzl", "bazel_integration_test", "bazel_integration_tests")
load("@rules_shell//shell:sh_binary.bzl", "sh_binary")

def gen_workspace(
        name,
        workspace_files = []):
    build_file_standins = [f for f in workspace_files if f.endswith("BUILD.test")]
    if len(build_file_standins) == 0:
        fail("Could not find any BUILD.test files")
    build_files = []
    for build_file_standin in build_file_standins:
        build_file = build_file_standin[:-len(".test")]
        native.genrule(
            name = build_file + "_gen",
            srcs = [build_file_standin],
            outs = [build_file],
            cmd = "cp $< $@",
            testonly = True,
        )
        build_files.append(build_file)

    native.filegroup(
        name = name,
        srcs = workspace_files + build_files,
        testonly = True,
    )

def rules_cc_integration_test(
        name,
        test_script,
        workspace,
        deps = [],
        tags = []):
    test_binary = name + "_test_runner"
    sh_binary(
        name = test_binary,
        srcs = ["//tests/integration:test_launcher.sh"],
        data = deps + [
            test_script,
            "//cc:all_files_for_testing",
            "//tests/integration:test_utils",
            "@rules_shell//shell/runfiles",
            "@rules_bazel_integration_test//tools:create_scratch_dir",
        ],
        deps = [
            "//tests/integration:test_utils",
            "@rules_shell//shell/runfiles",
        ],
        testonly = True,
    )

    bazel_integration_tests(
        name = name,
        test_runner = test_binary,
        bazel_binaries = bazel_binaries,
        bazel_versions = bazel_binaries.versions.all,
        env = {"TEST_RUNNER": "$(location %s)" % test_script},
        data = [
            test_script,
        ],
        workspace_path = Label(workspace).name,
        workspace_files = [workspace, "//:all_files_for_testing"],
        tags = tags + ["manual"],
    )

    selected_bazel = name + "_bazel_selected"
    native.alias(
        name = selected_bazel,
        actual = select({
            "//tests/integration:bazel_7": "@build_bazel_bazel_7_x//:bazel_binary",
            "//tests/integration:bazel_8": "@build_bazel_bazel_8_x//:bazel_binary",
            "//tests/integration:bazel_9": "@build_bazel_bazel_9_x//:bazel_binary",
            "//tests/integration:bazel_latest": "@build_bazel_bazel_last_green//:bazel_binary",
            "//conditions:default": "@build_bazel_bazel_last_green//:bazel_binary",
        }),
    )

    bazel_integration_test(
        name = name,
        test_runner = test_binary,
        bazel_binary = selected_bazel,
        env = {"TEST_RUNNER": "$(location %s)" % test_script},
        data = [test_script],
        workspace_path = Label(workspace).name,
        workspace_files = [workspace, "//:all_files_for_testing"],
        tags = tags,
    )
