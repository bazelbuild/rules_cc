load("//cc:defs.bzl", "cc_binary", "cc_library", "cc_test")
load("//examples:experimental_cc_shared_library.bzl", "LINKABLE_MORE_THAN_ONCE", "cc_shared_library")
load(":starlark_tests.bzl", "additional_inputs_test", "link_once_repeated_test", "linking_suffix_test", "paths_test")

package(
    default_visibility = ["//examples/test_cc_shared_library:__subpackages__"],
)

cc_test(
    name = "cc_test",
    srcs = ["main.cc"],
    dynamic_deps = ["foo_so"],
    deps = ["foo"],
)

cc_binary(
    name = "binary",
    srcs = ["main.cc"],
    dynamic_deps = ["foo_so"],
    deps = ["foo"],
)

cc_shared_library(
    name = "foo_so",
    additional_linker_inputs = [
        ":foo.lds",
        ":additional_script.txt",
    ],
    dynamic_deps = ["bar_so"],
    preloaded_deps = ["preloaded_dep"],
    static_deps = [
        "//examples/test_cc_shared_library:qux",
        "//examples/test_cc_shared_library:qux2",
    ],
    user_link_flags = [
        "-Wl,-rpath,kittens",
        "-Wl,--version-script=$(location :foo.lds)",
        "-Wl,--script=$(location :additional_script.txt)",
    ],
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
    name = "preloaded_dep",
    srcs = ["preloaded_dep.cc"],
    hdrs = ["preloaded_dep.h"],
)

cc_library(
    name = "foo",
    srcs = ["foo.cc"],
    hdrs = ["foo.h"],
    deps = [
        "preloaded_dep",
        "bar",
        "baz",
        # Not exported.
        "qux",
        "qux2",
    ],
)

cc_library(
    name = "baz",
    srcs = ["baz.cc"],
    hdrs = ["baz.h"],
)

cc_library(
    name = "qux",
    srcs = ["qux.cc"],
    hdrs = ["qux.h"],
)

cc_library(
    name = "qux2",
    srcs = ["qux2.cc"],
    hdrs = ["qux2.h"],
    tags = [LINKABLE_MORE_THAN_ONCE],
)

cc_shared_library(
    name = "bar_so",
    additional_linker_inputs = [
        ":bar.lds",
    ],
    static_deps = [
        "//examples/test_cc_shared_library:barX",
        "@test_repo//:bar",
        "//examples/test_cc_shared_library:qux2",
    ],
    user_link_flags = [
        "-Wl,--version-script=$(location :bar.lds)",
    ],
    exports = [
        "bar",
        "bar2",
        "@test_repo//:bar",
    ],
)

cc_library(
    name = "barX",
    srcs = ["bar.cc"],
    hdrs = ["bar.h"],
    deps = [
        "@test_repo//:bar",
    ],
)

cc_library(
    name = "bar",
    srcs = ["bar.cc"],
    hdrs = ["bar.h"],
    deps = [
        "barX",
        "qux2",
    ],
)

cc_library(
    name = "bar2",
    srcs = ["bar2.cc"],
    hdrs = ["bar2.h"],
)

cc_library(
    name = "bar3",
    srcs = ["bar3.cc"],
    hdrs = ["bar3.h"],
)

cc_library(
    name = "bar4",
    srcs = ["bar4.cc"],
    hdrs = ["bar4.h"],
)

sh_test(
    name = "cc_shared_library_integration_test",
    srcs = ["cc_shared_library_integration_test.sh"],
    data = [
        ":bar_so",
        ":binary",
        ":cc_test",
        ":foo_so",
    ],
)

linking_suffix_test(
    name = "linking_action_test",
    target_under_test = ":foo_so",
)

additional_inputs_test(
    name = "additional_inputs_test",
    target_under_test = ":foo_so",
)

link_once_repeated_test(
    name = "link_once_repeated_test",
    target_under_test = "//examples/test_cc_shared_library/failing_targets:should_fail_binary",
)

paths_test(
    name = "path_matching_test",
)
