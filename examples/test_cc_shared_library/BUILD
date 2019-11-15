load("//cc:defs.bzl", "cc_library")
load("//examples:experimental_cc_shared_library.bzl", "cc_shared_library")

cc_shared_library(
    name = "foo_so",
    dynamic_deps = ["bar_so"],
    visibility_file = "foo.lds",
    exports = [
        "foo",
        # Not a problem to export "baz" which is depended on by foo
        "baz",
        # Case1
        # This is fine. bar3 can be exported by "foo_so"
        # even though bar3 is linked statically by bar_so, since bar_so
        # doesn't export bar3 this is fine.
        "bar3",
        # Case2
        # This is fine. foo depends on bar4. Even though bar is
        # linked dynamically, when bar is pruned, we still have a dependency
        # edge to bar4 from foo. Also bar_so doesn't export bar4.
        #
        # Note that even though the target claims to export bar4. Unless the version script is
        # changed, the symbols from bar4 won't be exported.
        "bar4",
    ],
)

cc_library(
    name = "foo",
    srcs = ["foo.cc"],
    linked_statically_by = ["//examples/test_cc_shared_library:foo_so"],
    deps = [
        "bar",
        "baz",
        # Not exported.
        "qux",
    ],
)

cc_library(
    name = "baz",
    srcs = ["baz.cc"],
    linked_statically_by = ["//examples/test_cc_shared_library:foo_so"],
)

cc_library(
    name = "qux",
    srcs = ["qux.cc"],
    linked_statically_by = ["//examples/test_cc_shared_library:foo_so"],
)

cc_shared_library(
    name = "bar_so",
    visibility_file = "bar.lds",
    exports = [
        "bar",
        "bar2",
    ],
)

cc_library(
    name = "bar",
    srcs = ["bar.cc"],
    hdrs = ["bar.h"],
    linked_statically_by = [
        "//examples/test_cc_shared_library:bar_so",
    ],
)

cc_library(
    name = "bar2",
    srcs = ["bar2.cc"],
    linked_statically_by = [
        "//examples/test_cc_shared_library:bar_so",
        "//examples/test_cc_shared_library:foo_so",
    ],
)

cc_library(
    name = "bar3",
    srcs = ["bar3.cc"],
    linked_statically_by = [
        "//examples/test_cc_shared_library:bar_so",
        "//examples/test_cc_shared_library:foo_so",
    ],
)

cc_library(
    name = "bar4",
    srcs = ["bar4.cc"],
    linked_statically_by = [
        "//examples/test_cc_shared_library:bar_so",
        "//examples/test_cc_shared_library:foo_so",
    ],
)

sh_test(
    name = "cc_shared_library_integration_test",
    srcs = ["cc_shared_library_integration_test.sh"],
    data = [
        ":bar_so",
        ":foo_so",
    ],
)
