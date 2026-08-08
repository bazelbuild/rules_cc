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

"""Unit tests for libc_without_version()"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//cc/toolchains/impl:libc_version.bzl", "libc_without_version")

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

def libc_flag_test_suite(name):
    unittest.suite(
        name,
        libc_without_version_test,
    )
