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
