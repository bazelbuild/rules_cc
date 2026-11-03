"""Additional mock toolchains besides the mock C++ toolchain."""

def mock_additional_toolchains():
    # type: () -> None
    pass

# TODO(https://github.com/bazelbuild/bazel/pull/30373): Use a variable annotation
# when Bazel 8.8 is the minimum supported version.
ADDITIONAL_MOCK_TOOLCHAINS = []  # type: list[str]
