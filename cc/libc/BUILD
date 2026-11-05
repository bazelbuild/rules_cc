# Copyright 2026 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Config settings for C standard libraries identified by Bazel.

Targets that require libc-specific flags can use the config_settings defined in
this package in their select() statements.

Toolchains not shipped with Bazel are encouraged to use the same names to
identify C standard libraries as used below, but this is not enforced. A
toolchain's `target_libc` value may carry a version suffix (e.g. "glibc-2.31").
It is ignored by the config settings for C standard libraries below, but
determines whether the config settings for glibc versions (e.g.
`glibc_at_least_2.31`) match.

Example:

  cc_binary(
    name = "foo",
    srcs = ["foo.cc"],
    copts = select({
        "//cc/libc:glibc": [...],
        "//cc/libc:musl": [...],
        "//cc/libc:ucrt": [...],
        # Fallback case for an undetected C standard library.
        "//conditions:default": [...],
    }),
  )

If multiple targets use the same set of conditionally enabled flags, this can be
simplified by extracting the select expression into a Starlark constant.
"""

load("//cc/toolchains:libc_flag.bzl", "libc_flag", "libc_version_flag")
load("//cc/toolchains/impl:libc_version.bzl", "GLIBC_VERSIONS")

package(default_visibility = ["//visibility:public"])

licenses(["notice"])

libc_flag(name = "libc")

### Linux

# The GNU C Library (https://www.gnu.org/software/libc/).
config_setting(
    name = "glibc",
    flag_values = {":libc": "glibc"},
)

# For each glibc version starting with 2.15, `glibc_at_least_<version>` (e.g.
# `glibc_at_least_2.33`) matches if the current toolchain targets at least that
# version of glibc, as indicated by the version suffix of its `target_libc` value
# (e.g. "glibc-2.35"). None of them match if the toolchain doesn't indicate a
# version. Each of them is a specialization of `glibc` and of the settings for
# lower versions, so a select() can contain several of them:
#
#   local_defines = select({
#       "//cc/libc:glibc_at_least_2.33": ["HAVE_MALLINFO=1", "HAVE_MALLINFO2=1"],
#       "//cc/libc:glibc": ["HAVE_MALLINFO=1"],
#       "//conditions:default": [],
#   }),
[
    libc_version_flag(
        name = "_glibc_at_least_" + version,
        libc = ":libc",
        libc_name = "glibc",
        min_version = version,
        visibility = ["//visibility:private"],
    )
    for version in GLIBC_VERSIONS
]

[
    config_setting(
        name = "glibc_at_least_" + version,
        # Matching the flags of all lower versions makes this setting a
        # specialization of theirs.
        flag_values = dict(
            [(":libc", "glibc")] + [
                (
                    ":_glibc_at_least_" + lower_version,
                    "true",
                )
                for lower_version in GLIBC_VERSIONS[:i + 1]
            ],
        ),
    )
    for i, version in enumerate(GLIBC_VERSIONS)
]

# musl libc (https://musl.libc.org). Also used by Emscripten and, in the form
# of the derived wasi-libc, by WASI toolchains.
config_setting(
    name = "musl",
    flag_values = {":libc": "musl"},
)

# uClibc and its successor uClibc-ng (https://uclibc-ng.org).
config_setting(
    name = "uclibc",
    flag_values = {":libc": "uclibc"},
)

### Android

# Bionic, the C standard library of Android
# (https://android.googlesource.com/platform/bionic/).
config_setting(
    name = "bionic",
    flag_values = {":libc": "bionic"},
)

### Apple

# On Apple platforms, the C standard library is provided by libSystem. For
# historical reasons, toolchains identify it via the value "macosx" on all
# Apple platforms, not just macOS.
config_setting(
    name = "macosx",
    flag_values = {":libc": "macosx"},
)

### BSDs

# The C standard libraries developed as part of the respective BSD operating
# system.
config_setting(
    name = "freebsd",
    flag_values = {":libc": "freebsd"},
)

config_setting(
    name = "netbsd",
    flag_values = {":libc": "netbsd"},
)

config_setting(
    name = "openbsd",
    flag_values = {":libc": "openbsd"},
)

### Windows

# The legacy Microsoft Visual C++ Runtime (msvcrt.dll), which is also targeted
# by MinGW-w64 toolchains by default.
config_setting(
    name = "msvcrt",
    flag_values = {":libc": "msvcrt"},
)

# The Universal C Runtime (ucrtbase.dll), used by MSVC and clang-cl as well as
# the UCRT flavor of MinGW-w64 toolchains.
config_setting(
    name = "ucrt",
    flag_values = {":libc": "ucrt"},
)

# The MSYS2 runtime (msys-2.0.dll), a Cygwin-derived POSIX emulation layer
# targeted by MSYS2's gcc.
config_setting(
    name = "msys",
    flag_values = {":libc": "msys"},
)

### Embedded

# Newlib (https://sourceware.org/newlib/), commonly used by bare-metal
# toolchains such as arm-none-eabi-gcc.
config_setting(
    name = "newlib",
    flag_values = {":libc": "newlib"},
)

# Picolibc (https://github.com/picolibc/picolibc).
config_setting(
    name = "picolibc",
    flag_values = {":libc": "picolibc"},
)

# LLVM libc (https://libc.llvm.org).
config_setting(
    name = "llvm-libc",
    flag_values = {":libc": "llvm-libc"},
)

### WebAssembly

# wasi-libc (https://github.com/WebAssembly/wasi-libc), the musl-derived C
# standard library of WASI SDK toolchains.
config_setting(
    name = "wasi-libc",
    flag_values = {":libc": "wasi-libc"},
)

### Generic

config_setting(
    name = "none",
    flag_values = {":libc": "none"},
)
