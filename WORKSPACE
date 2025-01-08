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

http_archive(
    name = "rules_testing",
    sha256 = "02c62574631876a4e3b02a1820cb51167bb9cdcdea2381b2fa9d9b8b11c407c4",
    strip_prefix = "rules_testing-0.6.0",
    url = "https://github.com/bazelbuild/rules_testing/releases/download/v0.6.0/rules_testing-v0.6.0.tar.gz",
)

http_archive(
    name = "com_google_protobuf",
    sha256 = "008a11cc56f9b96679b4c285fd05f46d317d685be3ab524b2a310be0fbad987e",
    strip_prefix = "protobuf-29.3",
    url = "https://github.com/protocolbuffers/protobuf/releases/download/v29.3/protobuf-29.3.tar.gz",
)

http_archive(
    name = "googletest",
    integrity = "sha256-e0K01u1IgQxTYsJloX+uvpDcI3PIheUhZDnTeSfwKSY=",
    strip_prefix = "googletest-1.15.2",
    url = "https://github.com/google/googletest/releases/download/v1.15.2/googletest-1.15.2.tar.gz",
)
