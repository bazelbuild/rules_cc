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
"""Module extension for cc auto configuration."""

load("@bazel_features//:features.bzl", "bazel_features")
load("//cc/private/toolchain:cc_configure.bzl", "cc_autoconf", "cc_autoconf_toolchains")

def _cc_configure_extension_impl(ctx):
    cc_autoconf_toolchains(name = "local_config_cc_toolchains")
    cc_autoconf(name = "local_config_cc")
    if bazel_features.external_deps.extension_metadata_has_reproducible:
        return ctx.extension_metadata(reproducible = True)
    else:
        return None

cc_configure_extension = module_extension(implementation = _cc_configure_extension_impl)

def _compatibility_proxy_repo_impl(rctx):
    rctx.file("BUILD", "")
    bazel = native.bazel_version
    if not bazel or bazel >= "9":
        rctx.file(
            "proxy.bzl",
            """
load("@rules_cc//cc/private/rules_impl:cc_binary.bzl", _cc_binary = "cc_binary")
load("@rules_cc//cc/private/rules_impl:cc_import.bzl", _cc_import = "cc_import")
load("@rules_cc//cc/private/rules_impl:cc_library.bzl", _cc_library = "cc_library")
load("@rules_cc//cc/private/rules_impl:cc_shared_library.bzl", _cc_shared_library = "cc_shared_library")
load("@rules_cc//cc/private/rules_impl:cc_static_library.bzl", _cc_static_library = "cc_static_library")
load("@rules_cc//cc/private/rules_impl:cc_test.bzl", _cc_test = "cc_test")
load("@rules_cc//cc/private/rules_impl:objc_import.bzl", _objc_import = "objc_import")
load("@rules_cc//cc/private/rules_impl:objc_library.bzl", _objc_library = "objc_library")

cc_binary = _cc_binary
cc_import = _cc_import
cc_library = _cc_library
cc_shared_library = _cc_shared_library
cc_static_library = _cc_static_library
cc_test = _cc_test
objc_import = _objc_import
objc_library = _objc_library
            """,
        )
    else:
        rctx.file(
            "proxy.bzl",
            """
cc_binary = native.cc_binary
cc_import = native.cc_import
cc_library = native.cc_library
cc_shared_library = native.cc_shared_library
cc_static_library = getattr(native, "cc_static_library", None) # only in Bazel 8+
cc_test = native.cc_test
objc_import = native.objc_import
objc_library = native.objc_library
            """,
        )

_compatibility_proxy_repo_rule = repository_rule(
    _compatibility_proxy_repo_impl,
    # force reruns on server restarts to use correct native.bazel_version
    local = True,
)

def compatibility_proxy_repo():
    _compatibility_proxy_repo_rule(name = "cc_compatibility_proxy")

def _compat_proxy_impl(module_ctx):
    compatibility_proxy_repo()

    # module_ctx.extension_metadata has the paramater `reproducible` as of Bazel 7.1.0. We can't
    # test for it directly and would ideally use bazel_features to check for it, but don't want
    # to add a dependency for as long as WORKSPACE is still around. Thus, test for it by
    # checking the availability of another feature introduced in 7.1.0.
    if hasattr(module_ctx, "watch"):
        return module_ctx.extension_metadata(reproducible = True)
    else:
        return None

compatibility_proxy = module_extension(_compat_proxy_impl)
