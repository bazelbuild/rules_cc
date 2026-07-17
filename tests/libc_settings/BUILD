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

load("//cc:cc_binary.bzl", "cc_binary")
load(":libc_flag_test.bzl", "libc_flag_test_suite")

licenses(["notice"])

libc_flag_test_suite(name = "libc_flag_tests")

cc_binary(
    name = "main",
    srcs = ["main.cc"],
    local_defines = select(
        {
            "//cc/libc:bionic": ["LIBC=bionic"],
            "//cc/libc:glibc": ["LIBC=glibc"],
            "//cc/libc:macosx": ["LIBC=macosx"],
            "//cc/libc:msvcrt": ["LIBC=msvcrt"],
            "//cc/libc:msys": ["LIBC=msys"],
            "//cc/libc:musl": ["LIBC=musl"],
            "//cc/libc:ucrt": ["LIBC=ucrt"],
            "//conditions:default": [],
        },
        no_match_error = "C standard library not detected by Bazel",
    ),
)
