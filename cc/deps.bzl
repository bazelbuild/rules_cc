load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def rules_cc_deps():
    _maybe(
        http_archive,
        name = "bazel_skylib",
        sha256 = "2ef429f5d7ce7111263289644d233707dba35e39696377ebab8b0bc701f7818e",
        strip_prefix = "bazel-skylib-0.8.0",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/archive/0.8.0.tar.gz",
            "https://github.com/bazelbuild/bazel-skylib/archive/0.8.0.tar.gz",
        ],
    )

def _maybe(repo_rule, name, **kwargs):
    if name not in native.existing_rules():
        repo_rule(name = name, **kwargs)
