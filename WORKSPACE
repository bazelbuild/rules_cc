load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "six_archive",
    build_file = "@//third_party:six.BUILD",
    sha256 = "105f8d68616f8248e24bf0e9372ef04d3cc10104f1980f54d57b2ce73a5ad56a",
    strip_prefix = "six-1.10.0",
    urls = [
        "https://mirror.bazel.build/pypi.python.org/packages/source/s/six/six-1.10.0.tar.gz",
        "https://pypi.python.org/packages/source/s/six/six-1.10.0.tar.gz",
    ],
)

bind(
    name = "six",
    actual = "@six_archive//:six",
)

http_archive(
    name = "com_google_protobuf",
    sha256 = "3e933375ecc58d01e52705479b82f155aea2d02cc55d833f8773213e74f88363",
    strip_prefix = "protobuf-3.7.0",
    urls = [
        "https://mirror.bazel.build/github.com/protocolbuffers/protobuf/archive/protobuf-all-3.7.0.tar.gz",
        "https://github.com/protocolbuffers/protobuf/releases/download/v3.7.0/protobuf-all-3.7.0.tar.gz",
    ],
)

http_archive(
    name = "io_abseil_py",
    sha256 = "74a2203a9b4681851f4f1dfc17f2832e0a16bae0369b288b18b431cea63f0ee9",
    strip_prefix = "abseil-py-pypi-v0.6.1",
    urls = [
        "https://mirror.bazel.build/github.com/abseil/abseil-py/archive/pypi-v0.6.1.zip",
        "https://github.com/abseil/abseil-py/archive/pypi-v0.6.1.zip",
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

# TODO(https://github.com/protocolbuffers/protobuf/issues/5918: Remove when protobuf releases protobuf_deps.bzl)
http_archive(
    name = "net_zlib",
    build_file = "@com_google_protobuf//examples:third_party/zlib.BUILD",
    sha256 = "c3e5e9fdd5004dcb542feda5ee4f0ff0744628baf8ed2dd5d66f8ca1197cb1a1",
    strip_prefix = "zlib-1.2.11",
    urls = ["https://zlib.net/zlib-1.2.11.tar.gz"],
)

bind(
    name = "zlib",
    actual = "@net_zlib//:zlib",
)

# Go rules and proto support
http_archive(
    name = "io_bazel_rules_go",
    sha256 = "f04d2373bcaf8aa09bccb08a98a57e721306c8f6043a2a0ee610fd6853dcde3d",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/0.18.6/rules_go-0.18.6.tar.gz",
        "https://github.com/bazelbuild/rules_go/releases/download/0.18.6/rules_go-0.18.6.tar.gz",
    ],
)

# We're pinning to a commit because this project does not have a recent release.
# Nothing special about this commit, though.
http_archive(
    name = "com_google_googletest",
    sha256 = "0fb00ff413f6b9b80ccee44a374ca7a18af7315aea72a43c62f2acd1ca74e9b5",
    strip_prefix = "googletest-f13bbe2992d188e834339abe6f715b2b2f840a77",
    urls = [
        "https://mirror.bazel.build/github.com/google/googletest/archive/f13bbe2992d188e834339abe6f715b2b2f840a77.tar.gz",
        "https://github.com/google/googletest/archive/f13bbe2992d188e834339abe6f715b2b2f840a77.tar.gz",
    ],
)

load("@io_bazel_rules_go//go:deps.bzl", "go_rules_dependencies", "go_register_toolchains")

go_rules_dependencies()

go_register_toolchains()

load("//cc:repositories.bzl", "rules_cc_dependencies")

rules_cc_dependencies()
