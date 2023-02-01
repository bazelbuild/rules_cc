workspace(name = "rules_cc")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "bazel_skylib",
    sha256 = "74d544d96f4a5bb630d465ca8bbcfe231e3594e5aae57e1edbf17a6eb3ca2506",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.3.0/bazel-skylib-1.3.0.tar.gz",
        "https://github.com/bazelbuild/bazel-skylib/releases/download/1.3.0/bazel-skylib-1.3.0.tar.gz",
    ],
)

http_archive(
    name = "com_google_googletest",
    sha256 = "81964fe578e9bd7c94dfdb09c8e4d6e6759e19967e397dbea48d1c10e45d0df2",
    strip_prefix = "googletest-release-1.12.1",
    urls = [
        "https://mirror.bazel.build/github.com/google/googletest/archive/refs/tags/release-1.12.1.tar.gz",
        "https://github.com/google/googletest/archive/refs/tags/release-1.12.1.tar.gz",
    ],
)

http_archive(
    name = "io_abseil_py",
    sha256 = "c0bf3e839b7b1c58ac75e41f72a708597087a6c7dd0582aec4914e0d98ec8b04",
    strip_prefix = "abseil-py-1.3.0",
    urls = [
        "https://github.com/abseil/abseil-py/archive/refs/tags/v1.3.0.tar.gz",
    ],
)

http_archive(
    name = "io_bazel_rules_go",
    sha256 = "56d8c5a5c91e1af73eca71a6fab2ced959b67c86d12ba37feedb0a2dfea441a6",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/v0.37.0/rules_go-v0.37.0.zip",
        "https://github.com/bazelbuild/rules_go/releases/download/v0.37.0/rules_go-v0.37.0.zip",
    ],
)

http_archive(
    name = "platforms",
    sha256 = "5308fc1d8865406a49427ba24a9ab53087f17f5266a7aabbfc28823f3916e1ca",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/platforms/releases/download/0.0.6/platforms-0.0.6.tar.gz",
        "https://github.com/bazelbuild/platforms/releases/download/0.0.6/platforms-0.0.6.tar.gz",
    ],
)

http_archive(
    name = "py_mock",
    patch_cmds = [
        "mkdir -p py/mock",
        "mv mock.py py/mock/__init__.py",
        """echo 'licenses(["notice"])' > BUILD""",
        "touch py/BUILD",
        """echo 'py_library(name = "mock", srcs = ["__init__.py"], visibility = ["//visibility:public"],)' > py/mock/BUILD""",
    ],
    sha256 = "b839dd2d9c117c701430c149956918a423a9863b48b09c90e30a6013e7d2f44f",
    strip_prefix = "mock-1.0.1",
    urls = [
        "https://mirror.bazel.build/pypi.python.org/packages/source/m/mock/mock-1.0.1.tar.gz",
        "https://pypi.python.org/packages/source/m/mock/mock-1.0.1.tar.gz",
    ],
)

http_archive(
    name = "rules_proto",
    sha256 = "c9cc7f7be05e50ecd64f2b0dc2b9fd6eeb182c9cc55daf87014d605c31548818",
    strip_prefix = "rules_proto-3f1ab99b718e3e7dd86ebdc49c580aa6a126b1cd",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/rules_proto/archive/3f1ab99b718e3e7dd86ebdc49c580aa6a126b1cd.tar.gz",
        "https://github.com/bazelbuild/rules_proto/archive/3f1ab99b718e3e7dd86ebdc49c580aa6a126b1cd.tar.gz",
    ],
)

load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")

bazel_skylib_workspace()

load("@io_bazel_rules_go//go:deps.bzl", "go_register_toolchains", "go_rules_dependencies")

go_rules_dependencies()

go_register_toolchains(version = "1.19.4")

load("@rules_proto//proto:repositories.bzl", "rules_proto_dependencies", "rules_proto_toolchains")

rules_proto_dependencies()

rules_proto_toolchains()
