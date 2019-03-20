load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "six_archive",
    urls = [
        "https://mirror.bazel.build/pypi.python.org/packages/source/s/six/six-1.10.0.tar.gz",
        "https://pypi.python.org/packages/source/s/six/six-1.10.0.tar.gz",
    ],
    sha256 = "105f8d68616f8248e24bf0e9372ef04d3cc10104f1980f54d57b2ce73a5ad56a",
    strip_prefix = "six-1.10.0",
    build_file = "@//third_party:six.BUILD",
)

bind(
    name = "six",
    actual = "@six_archive//:six",
)

http_archive(
    name = "com_google_protobuf",
    sha256 = "2244b0308846bb22b4ff0bcc675e99290ff9f1115553ae9671eba1030af31bc0",
    strip_prefix = "protobuf-3.6.1.2",
    urls = [
        "https://mirror.bazel.build/github.com/google/protobuf/archive/v3.6.1.2.tar.gz",
        "https://github.com/google/protobuf/archive/v3.6.1.2.tar.gz",
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
    sha256 = "b839dd2d9c117c701430c149956918a423a9863b48b09c90e30a6013e7d2f44f",
    urls = [
        "https://mirror.bazel.build/pypi.python.org/packages/source/m/mock/mock-1.0.1.tar.gz",
        "https://pypi.python.org/packages/source/m/mock/mock-1.0.1.tar.gz",
    ],
    strip_prefix = "mock-1.0.1",
    patch_cmds = [
        "mkdir -p py/mock",
        "mv mock.py py/mock/__init__.py",
        """echo 'licenses(["notice"])' > BUILD""",
        "touch py/BUILD",
        """echo 'py_library(name = "mock", srcs = ["__init__.py"], visibility = ["//visibility:public"],)' > py/mock/BUILD""",
    ],
)

# Go rules and proto support
http_archive(
    name = "io_bazel_rules_go",
    sha256 = "77dfd303492f2634de7a660445ee2d3de2960cbd52f97d8c0dffa9362d3ddef9",
    strip_prefix = "rules_go-0.18.1",
    urls = [
        "https://github.com/bazelbuild/rules_go/archive/0.18.1.tar.gz",
    ],
)
load("@io_bazel_rules_go//go:def.bzl", "go_rules_dependencies", "go_register_toolchains")
go_rules_dependencies()
go_register_toolchains()
