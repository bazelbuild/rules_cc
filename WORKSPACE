workspace(name = "rules_cc")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "bazel_federation",
    url = "https://github.com/bazelbuild/bazel-federation/archive/01dc3f937696174c9764e23978f9d2e7105fd855.zip",
    sha256 = "64229f859bb0465fcdb654b31b3e547bbd5462005beaebbc09eb0ec735044cdd",
    strip_prefix = "bazel-federation-01dc3f937696174c9764e23978f9d2e7105fd855",
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
