load("@bazel_skylib//rules:common_settings.bzl", "string_flag")
load("@rules_shell//shell:sh_library.bzl", "sh_library")
load("//tests/integration:rules_cc_integration_test.bzl", "gen_workspace", "rules_cc_integration_test")

BAZEL_VERSIONS = [
    "7",
    "8",
    "9",
    "latest",
]

string_flag(
    name = "bazel_version",
    build_setting_default = "latest",
    values = BAZEL_VERSIONS,
)

[
    config_setting(
        name = "bazel_" + VERSION,
        flag_values = {
            ":bazel_version": VERSION,
        },
    )
    for VERSION in BAZEL_VERSIONS
]

sh_library(
    name = "test_utils",
    srcs = ["test_utils.sh"],
)

gen_workspace(
    "simple_compile",
    workspace_files = glob(["simple_compile/**"]),
)

rules_cc_integration_test(
    name = "simple_compile_test",
    test_script = "simple_compile_test.sh",
    workspace = "simple_compile",
)

rules_cc_integration_test(
    name = "stripped_compile_test",
    test_script = "stripped_compile_test.sh",
    workspace = "simple_compile",
)

rules_cc_integration_test(
    name = "no_recompile_on_shutdown_test",
    test_script = "no_recompile_on_shutdown_test.sh",
    workspace = "simple_compile",
)
