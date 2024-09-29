# Copyright 2024 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Exposing some helper functions for configure cc toolchains."""

load("//cc/private/toolchain:cc_configure.bzl", _MSVC_ENVVARS="MSVC_ENVVARS")
load("//cc/private/toolchain:lib_cc_configure.bzl", _escape_string="escape_string")
load("//cc/private/toolchain:windows_cc_configure.bzl", _find_vc_path="find_vc_path", _setup_vc_env_vars="setup_vc_env_vars")

MSVC_ENVVARS = _MSVC_ENVVARS

def find_vc_path(repository_ctx):
    return _find_vc_path(repository_ctx)

def setup_vc_env_vars(repository_ctx):
    return _setup_vc_env_vars(repository_ctx)

def escape_string(string):
    return _escape_string(string)