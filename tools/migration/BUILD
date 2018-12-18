# Copyright 2018 The Bazel Authors. All rights reserved.
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

package(default_visibility = ["//visibility:public"])

licenses(["notice"])  # Apache 2.0

py_binary(
    name = "legacy_fields_migrator",
    srcs = ["legacy_fields_migrator.py"],
    deps = [
        ":legacy_fields_migration_lib",
        "//third_party/com/github/bazelbuild/bazel/src/main/protobuf:crosstool_config_py_pb2",
        "@io_abseil_py//absl:app",
        "@io_abseil_py//absl/flags",
    ],
)

py_library(
    name = "legacy_fields_migration_lib",
    srcs = ["legacy_fields_migration_lib.py"],
    deps = [
        "//third_party/com/github/bazelbuild/bazel/src/main/protobuf:crosstool_config_py_pb2",
    ],
)

py_test(
    name = "legacy_fields_migration_lib_test",
    srcs = ["legacy_fields_migration_lib_test.py"],
    deps = [
        ":legacy_fields_migration_lib",
        "//third_party/com/github/bazelbuild/bazel/src/main/protobuf:crosstool_config_py_pb2",
    ],
)
