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
"""Helpers for dealing with the fact that features is a reserved attribute."""

# buildifier: disable=unnamed-macro
def disallow_features_attr(rule):
    def rule_wrapper(*, name, **kwargs):
        if "features" in kwargs:
            fail("Cannot use features in %s" % native.package_relative_label(name))
        rule(name = name, **kwargs)

    return rule_wrapper

def require_features_attr(rule):
    def rule_wrapper(*, name, features, **kwargs):
        rule(name = name, features_ = features, **kwargs)

    return rule_wrapper
