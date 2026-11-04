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

"""Tests for Objective-C compilation artifacts."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//cc/private/rules_impl:objc_compilation_artifacts_info.bzl", "CompilationArtifactsInfo")  # buildifier: disable=bzl-visibility

def _header_only_impl(ctx):
    env = unittest.begin(ctx)
    header = ctx.actions.declare_file(ctx.label.name + ".h")
    ctx.actions.write(header, "")
    artifacts = CompilationArtifactsInfo(hdrs = [header])
    asserts.equals(env, [header], artifacts.additional_hdrs)
    asserts.equals(env, None, artifacts.archive)
    return unittest.end(env)

header_only_compilation_artifacts_test = unittest.make(_header_only_impl)
