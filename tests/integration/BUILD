load("//tests/integration:rules_cc_integration_test.bzl", "rules_cc_integration_test")

exports_files(
    srcs = ["test_launcher.sh"],
    visibility = ["//tests:__subpackages__"],
)

rules_cc_integration_test(
    name = "cc_tests",
    shard_count = 2,
    test_script = "cc_tests.sh",
)

rules_cc_integration_test(
    name = "lto_tests",
    tags = [
        "no_macos",
        "no_windows",
    ],
    test_script = "lto_tests.sh",
)

rules_cc_integration_test(
    name = "cc_shared_library_tests",
    # These could probably be made to work on all CI platforms,
    # but the default toolchains are not properly configured for it.
    tags = [
        "no_macos",
        "no_windows",
    ],
    test_script = "cc_shared_library_tests.sh",
)
