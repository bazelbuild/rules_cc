workspace(name = "rules_cc")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "bazel_federation",
    url = "https://github.com/bazelbuild/bazel-federation/archive/f0e5eda7f0cbfe67f126ef4dacb18c89039b0506.zip", # 2019-09-30
    sha256 = "33222ab7bcc430f1ff1db8788c2e0118b749319dd572476c4fd02322d7d15792",
    strip_prefix = "bazel-federation-f0e5eda7f0cbfe67f126ef4dacb18c89039b0506",
    type = "zip",
)

load("@bazel_federation//:repositories.bzl", "rules_cc_deps")
rules_cc_deps()

load("@bazel_federation//setup:rules_cc.bzl", "rules_cc_setup")
rules_cc_setup()

#
# Dependencies for development of rules_cc itself.
#
load("//:internal_deps.bzl", "rules_cc_internal_deps")
rules_cc_internal_deps()

load("//:internal_setup.bzl", "rules_cc_internal_setup")
rules_cc_internal_setup()

# We're pinning to a commit because this project does not have a recent release.
# Nothing special about this commit, though.
http_archive(
    name = "com_google_googletest",
    sha256 = "55f8783e11fd8ba7b173a97aec11cec910d1b278a22e3906b5da74ba2c54fa41",
    strip_prefix = "googletest-cd17fa2abda2a2e4111cdabd62a87aea16835014",
    urls = [
        "https://mirror.bazel.build/github.com/google/googletest/archive/cd17fa2abda2a2e4111cdabd62a87aea16835014.tar.gz",
        "https://github.com/google/googletest/archive/cd17fa2abda2a2e4111cdabd62a87aea16835014.tar.gz",
    ],
)
