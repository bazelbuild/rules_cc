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

"""Unit tests for libc_without_version() and libc_version()"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//cc/toolchains/impl:libc_version.bzl", "libc_version", "libc_without_version")

def _libc_without_version_impl(ctx):
    env = unittest.begin(ctx)

    # Unversioned values are returned unchanged.
    asserts.equals(env, "glibc", libc_without_version("glibc"))
    asserts.equals(env, "macosx", libc_without_version("macosx"))
    asserts.equals(env, "unknown", libc_without_version("unknown"))
    asserts.equals(env, "", libc_without_version(""))

    # Version suffixes in the "glibc-2.2.2" format documented for
    # cc_common.create_cc_toolchain_config_info are stripped.
    asserts.equals(env, "glibc", libc_without_version("glibc-2.2.2"))
    asserts.equals(env, "glibc", libc_without_version("glibc-2"))
    asserts.equals(env, "musl", libc_without_version("musl-1.2.4"))
    asserts.equals(env, "newlib", libc_without_version("newlib-4.3.0.20230120"))

    # A "-" followed by a non-digit is part of the name, not a version suffix.
    asserts.equals(env, "wasi-libc", libc_without_version("wasi-libc"))
    asserts.equals(env, "llvm-libc", libc_without_version("llvm-libc"))
    asserts.equals(env, "wasi-libc", libc_without_version("wasi-libc-25"))

    # A trailing "-" is not a version suffix.
    asserts.equals(env, "glibc-", libc_without_version("glibc-"))

    return unittest.end(env)

libc_without_version_test = unittest.make(_libc_without_version_impl)

def _libc_version_impl(ctx):
    env = unittest.begin(ctx)

    # Versions with two or three numeric components are parsed.
    asserts.equals(env, (2, 31), libc_version("glibc-2.31"))
    asserts.equals(env, (2, 2, 2), libc_version("glibc-2.2.2"))
    asserts.equals(env, (1, 2, 4), libc_version("musl-1.2.4"))
    asserts.equals(env, (2, 0), libc_version("glibc-2.0"))

    # Versions are compared numerically.
    asserts.true(env, libc_version("glibc-2.31") > libc_version("glibc-2.9"))
    asserts.true(env, libc_version("glibc-2.31.1") > libc_version("glibc-2.31"))
    asserts.true(env, libc_version("glibc-3.0") > libc_version("glibc-2.44"))

    # Values without a version suffix have no version.
    asserts.equals(env, None, libc_version("glibc"))
    asserts.equals(env, None, libc_version("wasi-libc"))
    asserts.equals(env, None, libc_version("unknown"))
    asserts.equals(env, None, libc_version(""))

    # Other version suffixes are not parsed.
    asserts.equals(env, None, libc_version("glibc-2"))
    asserts.equals(env, None, libc_version("wasi-libc-25"))
    asserts.equals(env, None, libc_version("newlib-4.3.0.20230120"))
    asserts.equals(env, None, libc_version("glibc-2.31-vendor"))
    asserts.equals(env, None, libc_version("glibc-2.x"))
    asserts.equals(env, None, libc_version("glibc-2..31"))
    asserts.equals(env, None, libc_version("glibc-2.031"))

    return unittest.end(env)

libc_version_test = unittest.make(_libc_version_impl)

def libc_flag_test_suite(name):
    unittest.suite(
        name,
        libc_without_version_test,
        libc_version_test,
    )
