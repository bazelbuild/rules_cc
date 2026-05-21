load("@bazel_binaries//:defs.bzl", "bazel_binaries")
load("@rules_bazel_integration_test//bazel_integration_test:defs.bzl", "bazel_integration_test", "bazel_integration_tests")
load("@rules_shell//shell:sh_binary.bzl", "sh_binary")
load("@rules_shell//shell:sh_test.bzl", "sh_test")

def package_workspace_impl(ctx):
    out_dir = ctx.actions.declare_directory(ctx.label.name)

    commands = []
    pkg_root = ctx.label.package
    print(pkg_root)
    for f in ctx.files.srcs:
        f_path = f.short_path
        #if f.short_path.startswith(pkg_root + "/"):
        #    f_path = f_path[len(pkg_root) + 1:]
        dest_path = out_dir.path + "/" + f_path
        dest_parent = dest_path.rsplit("/", 1)[0]

        commands.append(
            "mkdir -p \"{dest_parent}\" && cp \"{src}\" \"{dest}\"".format(
                dest_parent = dest_parent,
                src = f.path,
                dest = dest_path,
            )
        )

    ctx.actions.run_shell(
        inputs = ctx.files.srcs,
        outputs = [out_dir],
        command = " && ".join(commands),
        progress_message = "Creating workspace '{}'".format(ctx.label.name)
    )
    return DefaultInfo(files = depset([out_dir]))

package_workspace = rule(
    implementation = package_workspace_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True),
    }
)

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

    #native.filegroup(
    #    name = name,
    #    srcs = workspace_files + build_files + ["//:all_files_for_testing"],
    #    testonly = True,
    #)
    package_workspace(
        name = name,
        srcs = workspace_files + build_files + ["//:all_files_for_testing"],
        testonly = True,
    )

def common_prefix(files):
    if not files:
        return ""
    walking = files[0]
    others = files[1:]

    for idx, c in enumerate(walking.elems()):
        for other in others:
            if other[idx] != c:
                return walking[:idx]
    return walking
        

def rules_cc_integration_test(
        name,
        test_script,
        workspace,
        workspace_name,
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

    # bazel_integration_tests(
    #     name = name,
    #     test_runner = test_binary,
    #     bazel_binaries = bazel_binaries,
    #     bazel_versions = bazel_binaries.versions.all,
    #     env = {"TEST_RUNNER": "$(location %s)" % test_script},
    #     data = [
    #         test_script,
    #     ],
    #     workspace_path = Label(workspace).name,
    #     workspace_files = [workspace, "//:all_files_for_testing"],
    #     tags = tags + ["manual"],
    # )

    # selected_bazel = name + "_bazel_selected"
    # native.alias(
    #     name = selected_bazel,
    #     actual = select({
    #         "//tests/integration:bazel_7": "@build_bazel_bazel_7_x//:bazel_binary",
    #         "//tests/integration:bazel_8": "@build_bazel_bazel_8_x//:bazel_binary",
    #         "//tests/integration:bazel_9": "@build_bazel_bazel_9_x//:bazel_binary",
    #         "//tests/integration:bazel_latest": "@build_bazel_bazel_last_green//:bazel_binary",
    #         "//conditions:default": "@build_bazel_bazel_last_green//:bazel_binary",
    #     }),
    # )

    # bazel_integration_test(
    #     name = name,
    #     test_runner = test_binary,
    #     bazel_binary = selected_bazel,
    #     env = {"TEST_RUNNER": "$(location %s)" % test_script},
    #     data = [test_script],
    #     workspace_path = Label(workspace).name,
    #     workspace_files = [workspace, "//:all_files_for_testing"],
    #     tags = tags,
    # )

    selected_bazel = name + "_bazel_selected"
    native.alias(
        name = selected_bazel,
        actual = select({
            "//tests/integration:bazel_7": "@bazel_7//file",
            "//tests/integration:bazel_8": "@bazel_8//file",
            "//tests/integration:bazel_9": "@bazel_9//file",
            "//conditions:default": "@local_bazel//:bazel_bin",
        })
    )

    #workspace_dir = name + "_workspace"
    #package_workspace(
    #    name = workspace_dir,
    #    srcs = [workspace],
    #    testonly = True,
    #)

    sh_test(
        name = name,
        srcs = [
            "//tests/integration:test_launcher.sh",
        ],
        data = [
            selected_bazel,
            test_script,
            "//tests/integration:test_utils",
            "//tests/integration:platform_utils",
            "@rules_shell//shell/runfiles",
            Label(workspace),
            Label(workspace_name),
        ],
        env = {
            "TEST_RUNNER": "$(location %s)" % test_script,
            "BAZEL_BINARY": "$(rlocationpath %s)" % selected_bazel,
            "WORKSPACE_DIR": "$(location %s)" % Label(workspace),
            "WORKSPACE_PATH": "$(location %s)" % Label(workspace_name),
        },
        deps = [
            "//tests/integration:test_utils",
            "@rules_shell//shell/runfiles",
        ],
    )
