# Copyright 2024 The Bazel Authors. All rights reserved.
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
"""cc_toolchain rule"""

load("@bazel_features//:features.bzl", "bazel_features")

def cc_toolchain(**kwargs):
    """
    cc_toolchain rule

    Wrapper around native.cc_toolchain that removes features that are not
    supported by the C++ toolchain.

    Args:
        **kwargs: Arguments to pass to native.cc_toolchain.
    """
    if "generate_modmap" in kwargs:
        if not bazel_features.cc.cc_toolchain_has_generate_modmap:
            kwargs.pop("generate_modmap")
    native.cc_toolchain(**kwargs)  # buildifier: disable=native-cc-toolchain
