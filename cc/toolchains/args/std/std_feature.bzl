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
"""Helper for defining C and C++ language standard features."""

load("//cc/toolchains:args.bzl", "cc_args")
load("//cc/toolchains:feature.bzl", "cc_feature")

visibility("//cc/toolchains/args/std/...")

def cc_std_feature(name, actions, mutually_exclusive, args = None, **kwargs):
    """Defines a `cc_feature` that selects a C or C++ language standard.

    The feature is named after the value passed to the GCC/Clang `-std=` flag
    (e.g. `c17` or `c++20`) so that `features = ["c++20"]` reads naturally.

    Args:
        name: (str) The name of the feature. This is also the value of `-std=`.
        actions: (List[Label]) The actions that the flag applies to.
        mutually_exclusive: (List[Label]) The `cc_mutually_exclusive_category`
          this feature belongs to, so that only one standard per language can be
          enabled at a time.
        args: (List[str]) The flags to pass. Defaults to `-std=<name>`.
        **kwargs: Additional arguments forwarded to `cc_feature`.
    """
    cc_args(
        name = name + "_args",
        actions = actions,
        args = args or ["-std=" + name],
        visibility = ["//visibility:private"],
    )
    cc_feature(
        name = name,
        feature_name = name,
        args = [":" + name + "_args"],
        mutually_exclusive = mutually_exclusive,
        **kwargs
    )
