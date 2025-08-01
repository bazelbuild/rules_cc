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
"""A failing cc_proto_library rule."""

load("//cc/common:cc_info.bzl", "CcInfo")

def _impl(ctx):
    fail("Use cc_proto_library from com_google_protobuf")

cc_proto_library = rule(
    implementation = _impl,
    providers = [CcInfo],
    doc = "Do not use. The rule always fails",
    attrs = {
        "deps": attr.label_list(),
    },
)
