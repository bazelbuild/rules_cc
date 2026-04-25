workspace(name = "rules_cc")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "bazel_skylib",
    sha256 = "fa01292859726603e3cd3a0f3f29625e68f4d2b165647c72908045027473e933",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.8.0/bazel-skylib-1.8.0.tar.gz",
        "https://github.com/bazelbuild/bazel-skylib/releases/download/1.8.0/bazel-skylib-1.8.0.tar.gz",
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
    sha256 = "20721f63908879c083f94869e618ea8d4ff5edb91ff9a72a2ebee357fdbc352d",
    strip_prefix = "rules_shell-0.8.0",
    url = "https://github.com/bazelbuild/rules_shell/releases/download/v0.8.0/rules_shell-v0.8.0.tar.gz",
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

# Required commit 9f66dfd "Add feature for cc.compile_is_starlark"
# TODO: pzembrod - Change to a released version again when the commit is in a release.
http_archive(
    name = "bazel_features",
    sha256 = "sha256-Q+hJsju3CWDN1K9InhbErlZNk093AewwEPnI3BodltQ=",
    strip_prefix = "bazel_features-9f66dfd288cec395f373950b7c8eaaf11c2624fc",
    url = "https://github.com/bazel-contrib/bazel_features/archive/9f66dfd288cec395f373950b7c8eaaf11c2624fc.tar.gz",
)

load("@bazel_features//:deps.bzl", "bazel_features_deps")

bazel_features_deps()

load("//cc:extensions.bzl", "compatibility_proxy_repo")

compatibility_proxy_repo()
