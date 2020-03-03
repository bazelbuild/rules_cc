load("//cc:defs.bzl", "cc_binary")

package(
    default_visibility = ["//examples/test_cc_shared_library:__pkg__"],
)

cc_binary(
    name = "should_fail_binary",
    dynamic_deps = ["//examples/test_cc_shared_library:foo_so"],
    tags = [
        "manual",
        "nobuilder",
    ],
    deps = [
        "//examples/test_cc_shared_library:foo",
        "//examples/test_cc_shared_library:qux",
    ],
)
