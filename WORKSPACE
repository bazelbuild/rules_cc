load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "six_archive",
    urls = [
        "http://mirror.bazel.build/pypi.python.org/packages/source/s/six/six-1.10.0.tar.gz",
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
    sha256 = "d6618d117698132dadf0f830b762315807dc424ba36ab9183f1f436008a2fdb6",
    strip_prefix = "protobuf-3.6.1.2",
    urls = ["https://github.com/google/protobuf/archive/v3.6.1.2.zip"],
)

http_archive(
    name = "io_abseil_py",
    sha256 = "74a2203a9b4681851f4f1dfc17f2832e0a16bae0369b288b18b431cea63f0ee9",
    strip_prefix = "abseil-py-pypi-v0.6.1",
    urls = ["https://github.com/abseil/abseil-py/archive/pypi-v0.6.1.zip"],
)
