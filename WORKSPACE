workspace(name = "rules_cc")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "bazel_skylib",
    sha256 = "bc283cdfcd526a52c3201279cda4bc298652efa898b10b4db0837dc51652756f",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.7.1/bazel-skylib-1.7.1.tar.gz",
        "https://github.com/bazelbuild/bazel-skylib/releases/download/1.7.1/bazel-skylib-1.7.1.tar.gz",
    ],
)

http_archive(
    name = "platforms",
    sha256 = "218efe8ee736d26a3572663b374a253c012b716d8af0c07e842e82f238a0a7ee",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/platforms/releases/download/0.0.10/platforms-0.0.10.tar.gz",
        "https://github.com/bazelbuild/platforms/releases/download/0.0.10/platforms-0.0.10.tar.gz",
    ],
)

load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")

bazel_skylib_workspace()

http_archive(
    name = "rules_shell",
    sha256 = "410e8ff32e018b9efd2743507e7595c26e2628567c42224411ff533b57d27c28",
    strip_prefix = "rules_shell-0.2.0",
    url = "https://github.com/bazelbuild/rules_shell/releases/download/v0.2.0/rules_shell-v0.2.0.tar.gz",
)

load("@rules_shell//shell:repositories.bzl", "rules_shell_dependencies", "rules_shell_toolchains")

rules_shell_dependencies()

rules_shell_toolchains()

# Required commit 26a0b7d "Add CollectionSubject.contains_no_duplicates"
# TODO: pzembrod - Change to a released version again when the commit is in a release.
http_archive(
    name = "rules_testing",
    integrity = "sha256-Fv1hcAnEWf4QxN9MhAcL9MBowNFqYdeFhZAApqdaY6w=",
    strip_prefix = "rules_testing-26a0b7d0b21c21338bb2f5ce693eac14aa24e323",
    url = "https://github.com/bazelbuild/rules_testing/archive/26a0b7d0b21c21338bb2f5ce693eac14aa24e323.tar.gz",
)

http_archive(
    name = "googletest",
    integrity = "sha256-e0K01u1IgQxTYsJloX+uvpDcI3PIheUhZDnTeSfwKSY=",
    strip_prefix = "googletest-1.15.2",
    url = "https://github.com/google/googletest/releases/download/v1.15.2/googletest-1.15.2.tar.gz",
)

http_archive(
    name = "bazel_features",
    sha256 = "c26b4e69cf02fea24511a108d158188b9d8174426311aac59ce803a78d107648",
    strip_prefix = "bazel_features-1.43.0",
    url = "https://github.com/bazel-contrib/bazel_features/releases/download/v1.43.0/bazel_features-v1.43.0.tar.gz",
)

load("@bazel_features//:deps.bzl", "bazel_features_deps")

bazel_features_deps()

load("//cc:extensions.bzl", "compatibility_proxy_repo")

compatibility_proxy_repo()

http_archive(
    name = "rules_bazel_integration_test",
    sha256 = "caadcd3adafc2cdcd4b020cf0ae530ddab4dc61201a9948473909b75a91e9192",
    urls = [
        "https://github.com/bazel-contrib/rules_bazel_integration_test/releases/download/v0.35.0/rules_bazel_integration_test.v0.35.0.tar.gz",
    ],
)

load("@rules_bazel_integration_test//bazel_integration_test:deps.bzl", "bazel_integration_test_rules_dependencies")

bazel_integration_test_rules_dependencies()

load("@cgrindel_bazel_starlib//:deps.bzl", "bazel_starlib_dependencies")

bazel_starlib_dependencies()

load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")

bazel_skylib_workspace()

load("@rules_bazel_integration_test//bazel_integration_test:defs.bzl", "bazel_binaries")

bazel_binaries(versions = [
    "//:.bazelversion",
    "8.5.1",
    "last_green",
])
