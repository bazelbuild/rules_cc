load("@bazel_skylib//rules:native_binary.bzl", "native_binary")
load("@bazel_skylib//rules/directory:directory.bzl", "directory")

package(default_visibility = ["//tests/rule_based_toolchain:__subpackages__"])

directory(
    name = "directory",
    srcs = glob(
        ["*"],
        exclude = ["BUILD"],
    ),
)

exports_files(
    glob(
        ["*"],
        exclude = ["BUILD"],
    ),
)

native_binary(
    name = "bin_wrapper",
    src = "bin_wrapper.sh",
    out = "bin_wrapper",
    data = [":bin"],
)

filegroup(
    name = "multiple",
    srcs = [
        "multiple1",
        "multiple2",
    ],
)

# Analysis_test is unable to depend on source files directly, but it can depend
# on a filegroup containing a single file.
filegroup(
    name = "bin_filegroup",
    srcs = ["bin"],
)

# Analysis_test is unable to depend on source files directly, but it can depend
# on a filegroup containing a single file.
filegroup(
    name = "bin_wrapper_filegroup",
    srcs = ["bin_wrapper.sh"],
)
