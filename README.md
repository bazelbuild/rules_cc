# C++ rules for Bazel

* Postsubmit [![Build status](https://badge.buildkite.com/f03592ae2d7d25a2abc2a2ba776e704823fa17fd3e061f5103.svg?branch=main)](https://buildkite.com/bazel/rules-cc)

This repository contains C, C++, and Objective-C language support for the [Bazel
build system](https://bazel.build/).

For this module's main reference, see the Bazel
[documentation](https://bazel.build/reference/be/c-cpp).

# Get Started

## Install Bazel

Follow the official instructions to [Install
Bazel](https://bazel.build/install).

## Add rules_cc to your MODULE.bazel

Add the [latest release](https://registry.bazel.build/modules/rules_cc) to your [MODULE.bazel project file](https://bazel.build/external/overview).

## Declare a build target

In a `BUILD.bazel` file, import and use the rules:

```python
load("@rules_cc//cc:cc_binary.bzl", "cc_binary")

cc_binary(
    name = "hello_world",
    srcs = ["hello_world.cc"],
)
```

## Build and run your project

Build and run your C/C++ binary with one command:

```console
$ bazel run hello_world
```

To build the project without running the binary, use Bazel's `build` subcommand:

```console
$ bazel build hello_world
```

# Toolchains

## Default autoconfigured toolchain

rules_cc includes an auto-configured toolchain that uses the local compiler
installed on the host machine.

You can disable the autoconfigured C/C++ toolchain by adding the following Bazel
flag to your project's [`.bazelrc` file](https://bazel.build/run/bazelrc):

```
--repo_env=BAZEL_DO_NOT_DETECT_CPP_TOOLCHAIN=1
```

## Hermetic toolchains

Configuring a [hermetic](https://bazel.build/basics/hermeticity) toolchain makes
your build more deterministic. rules_cc itself does not yet offer a hermetic
toolchain distribution. Other community owned and maintained projects offer
hermetic C/C++ toolchains:

- GCC (Linux only): <https://github.com/f0rmiga/gcc-toolchain>
- Hermetic LLVM: <https://github.com/hermeticbuild/hermetic-llvm>
- LLVM: <https://github.com/bazel-contrib/toolchains_llvm>
- zig cc: <https://github.com/uber/hermetic_cc_toolchain>

# Contributing

Bazel and `rules_cc` are the work of many contributors. We appreciate your help!

To contribute, please read the contribution guidelines: [CONTRIBUTING.md](https://github.com/bazelbuild/rules_cc/blob/main/CONTRIBUTING.md).

Note that the `rules_cc` use the GitHub issue tracker for bug reports and feature requests only.
For asking questions see:

* [Stack Overflow](https://stackoverflow.com/questions/tagged/bazel)
* [`rules_cc` mailing list](https://groups.google.com/forum/#!forum/cc-bazel-discuss)
* Slack channel `#cc` on [slack.bazel.build](https://slack.bazel.build)
