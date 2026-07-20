load("@bazel_features//:features.bzl", "bazel_features")  # copybara-uncomment-this-please

#buildifier: disable=bzl-visibility
load("@bazel_features//private:util.bzl", _features_ge = "ge")
load("//tests/integration:rules_cc_integration_test.bzl", "rules_cc_integration_test")

exports_files(
    srcs = ["test_launcher.sh"],
    visibility = ["//tests:__subpackages__"],
)

rules_cc_integration_test(
    name = "cc_tests",
    shard_count = 4,
    test_script = "cc_tests.sh",
)

rules_cc_integration_test(
    name = "lto_tests",
    target_compatible_with = select({
        "@platforms//os:macos": ["@platforms//:incompatible"],
        "@platforms//os:windows": ["@platforms//:incompatible"],
        "//conditions:default": [],
    }),
    test_script = "lto_tests.sh",
)

rules_cc_integration_test(
    name = "cc_shared_library_tests",
    # These could probably be made to work on all CI platforms,
    # but the default toolchains are not properly configured for it.
    target_compatible_with = select({
        "@platforms//os:macos": ["@platforms//:incompatible"],
        "@platforms//os:windows": ["@platforms//:incompatible"],
        "//conditions:default": [],
    }),
    test_script = "cc_shared_library_tests.sh",
)

rules_cc_integration_test(
    name = "fission_tests",
    target_compatible_with = select({
        "@platforms//os:macos": ["@platforms//:incompatible"],
        "@platforms//os:windows": ["@platforms//:incompatible"],
        "//conditions:default": [],
    }),
    test_script = "fission_tests.sh",
)

VERSION_GATE = [] if bazel_features.cc.cc_common_is_in_rules_cc else ["@platforms//:incompatible"]  # copybara-uncomment-this-please
# VERSION_GATE = ["@platforms//:incompatible"]  # copybara-comment-this-out-please

rules_cc_integration_test(
    name = "cc_static_library_failure_tests",
    tags = ["notap"],
    target_compatible_with = select({
        "@platforms//os:macos": ["@platforms//:incompatible"],
        "//conditions:default": VERSION_GATE,
    }),
    test_script = "cc_static_library_failure_tests.sh",
)

rules_cc_integration_test(
    name = "cc_shared_library_toolchain_tests",
    # These could probably be made to work on all CI platforms,
    # but the default toolchains are not properly configured for it.
    target_compatible_with = select({
        "@platforms//os:macos": ["@platforms//:incompatible"],
        "@platforms//os:windows": ["@platforms//:incompatible"],
        "//conditions:default": [] if _features_ge("9.2.0") else ["@platforms//:incompatible"],
    }),
    test_script = "cc_shared_library_toolchain_tests.sh",
)
