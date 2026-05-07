load(":cc_binary_configured_target_tests.bzl", "cc_binary_configured_target_tests")
load(":cc_common_test.bzl", "cc_common_tests")
load(":cc_library_configured_target_tests.bzl", "cc_library_configured_target_tests")
# load(":cc_objc_library_configured_target_tests.bzl", "cc_objc_library_configured_target_tests")

cc_binary_configured_target_tests(name = "cc_binary_configured_target_tests")

cc_common_tests(name = "cc_common_tests")

cc_library_configured_target_tests(name = "cc_library_configured_target_tests")

# TODO(b/360366113): Re-enable when removing .a files from runfiles.
# The change this was meant to test may break rules_apple.
# cc_objc_library_configured_target_tests(name = "cc_objc_library_configured_target_tests")
