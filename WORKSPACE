workspace(name = "rules_cc")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "bazel_federation",
    url = "https://github.com/bazelbuild/bazel-federation/archive/ed880c20ec6112984caa47ddc6489028dbcc66e2.zip",
    sha256 = "95339d2002756bdde910c93b6c42248725a7c2b61629585f08580cc4f07d1805",
    strip_prefix = "bazel-federation-ed880c20ec6112984caa47ddc6489028dbcc66e2",
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
    sha256 = "0fb00ff413f6b9b80ccee44a374ca7a18af7315aea72a43c62f2acd1ca74e9b5",
    strip_prefix = "googletest-f13bbe2992d188e834339abe6f715b2b2f840a77",
    urls = [
        "https://mirror.bazel.build/github.com/google/googletest/archive/f13bbe2992d188e834339abe6f715b2b2f840a77.tar.gz",
        "https://github.com/google/googletest/archive/f13bbe2992d188e834339abe6f715b2b2f840a77.tar.gz",
    ],
)
