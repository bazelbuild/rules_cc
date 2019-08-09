load("@bazel_federation//:repositories.bzl", "bazel_skylib", "protobuf", "rules_go")
load("@bazel_federation//:third_party_repositories.bzl", "abseil_py", "py_mock", "six", "zlib")

def rules_cc_internal_deps():
    bazel_skylib()
    protobuf()
    rules_go()

    abseil_py()
    py_mock()
    six()
    zlib()
