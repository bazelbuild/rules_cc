# Copyright 2025 The Bazel Authors. All rights reserved.
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

load("//cc:cc_library.bzl", "cc_library")
load("//cc:cc_test.bzl", "cc_test")

licenses(["notice"])

cc_library(
    name = "lib",
    srcs = [
        "lib/lib.c",
        "lib/private/private.c",
        "lib/private/private.h",
    ],
    hdrs = ["lib/include/public.h"],
    includes = [
        "lib/include",
    ],
    local_includes = [
        "lib/private",
    ],
)

cc_test(
    name = "bin",
    srcs = [
        "binary.c",
        "binary_helper.c",
        "private/binary_helper.h",
    ],
    local_includes = [
        "private",
    ],
    deps = [":lib"],
)
