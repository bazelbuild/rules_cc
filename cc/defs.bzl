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

"""Starlark rules for building C++ projects."""

load("//cc/private/rules_impl:cc_flags_supplier.bzl", _cc_flags_supplier = "cc_flags_supplier")
load("//cc/private/rules_impl:compiler_flag.bzl", _compiler_flag = "compiler_flag")
load("//cc/private/rules_impl:native.bzl", "NativeCcInfo", "NativeCcToolchainConfigInfo", "NativeDebugPackageInfo", "native_cc_common")

_MIGRATION_TAG = "__CC_RULES_MIGRATION_DO_NOT_USE_WILL_BREAK__"

# TODO(bazel-team): To avoid breaking changes, if the below are no longer
# forwarding to native rules, flag @bazel_tools@bazel_tools//tools/cpp:link_extra_libs
# should either: (a) alias the flag @rules_cc//:link_extra_libs, or (b) be
# added as a dependency to @rules_cc//:link_extra_lib. The intermediate library
# @bazel_tools@bazel_tools//tools/cpp:link_extra_lib should either be added as a dependency
# to @rules_cc//:link_extra_lib, or removed entirely (if possible).
_LINK_EXTRA_LIB = "@rules_cc//:link_extra_lib"  # copybara-use-repo-external-label

def _add_tags(attrs, is_binary = False):
    if "tags" in attrs and attrs["tags"] != None:
        attrs["tags"] = attrs["tags"] + [_MIGRATION_TAG]
    else:
        attrs["tags"] = [_MIGRATION_TAG]

    if is_binary:
        is_library = "linkshared" in attrs and attrs["linkshared"]

        # Executable builds also include the "link_extra_lib" library.
        if not is_library:
            if "deps" in attrs and attrs["deps"] != None:
                attrs["deps"] = attrs["deps"] + [_LINK_EXTRA_LIB]
            else:
                attrs["deps"] = [_LINK_EXTRA_LIB]

    return attrs

def cc_binary(**attrs):
    """Bazel cc_binary rule.

    https://docs.bazel.build/versions/main/be/c-cpp.html#cc_binary

    Args:
      **attrs: Rule attributes
    """

    # buildifier: disable=native-cc
    native.cc_binary(**_add_tags(attrs, True))

def cc_test(**attrs):
    """Bazel cc_test rule.

    https://docs.bazel.build/versions/main/be/c-cpp.html#cc_test

    Args:
      **attrs: Rule attributes
    """

    # buildifier: disable=native-cc
    native.cc_test(**_add_tags(attrs, True))

def cc_library(**attrs):
    """Bazel cc_library rule.

    https://docs.bazel.build/versions/main/be/c-cpp.html#cc_library

    Args:
      **attrs: Rule attributes
    """

    # buildifier: disable=native-cc
    native.cc_library(**_add_tags(attrs))

def cc_import(**attrs):
    """Bazel cc_import rule.

    https://docs.bazel.build/versions/main/be/c-cpp.html#cc_import

    Args:
      **attrs: Rule attributes
    """

    # buildifier: disable=native-cc
    native.cc_import(**_add_tags(attrs))

def cc_proto_library(**attrs):
    """Bazel cc_proto_library rule.

    https://docs.bazel.build/versions/main/be/c-cpp.html#cc_proto_library

    Args:
      **attrs: Rule attributes
    """

    # buildifier: disable=native-cc-proto
    native.cc_proto_library(**_add_tags(attrs))

def fdo_prefetch_hints(**attrs):
    """Bazel fdo_prefetch_hints rule.

    https://docs.bazel.build/versions/main/be/c-cpp.html#fdo_prefetch_hints

    Args:
      **attrs: Rule attributes
    """

    # buildifier: disable=native-cc
    native.fdo_prefetch_hints(**_add_tags(attrs))

def fdo_profile(**attrs):
    """Bazel fdo_profile rule.

    https://docs.bazel.build/versions/main/be/c-cpp.html#fdo_profile

    Args:
      **attrs: Rule attributes
    """

    # buildifier: disable=native-cc
    native.fdo_profile(**_add_tags(attrs))

def cc_toolchain(**attrs):
    """Bazel cc_toolchain rule.

    https://docs.bazel.build/versions/main/be/c-cpp.html#cc_toolchain

    Args:
      **attrs: Rule attributes
    """

    # buildifier: disable=native-cc
    native.cc_toolchain(**_add_tags(attrs))

def cc_toolchain_suite(**attrs):
    """Bazel cc_toolchain_suite rule.

    https://docs.bazel.build/versions/main/be/c-cpp.html#cc_toolchain_suite

    Args:
      **attrs: Rule attributes
    """

    # buildifier: disable=native-cc
    native.cc_toolchain_suite(**_add_tags(attrs))

def objc_library(**attrs):
    """Bazel objc_library rule.

    https://docs.bazel.build/versions/main/be/objective-c.html#objc_library

    Args:
      **attrs: Rule attributes
    """

    # buildifier: disable=native-cc
    native.objc_library(**_add_tags(attrs))

def objc_import(**attrs):
    """Bazel objc_import rule.

    https://docs.bazel.build/versions/main/be/objective-c.html#objc_import

    Args:
      **attrs: Rule attributes
    """

    # buildifier: disable=native-cc
    native.objc_import(**_add_tags(attrs))

def cc_flags_supplier(**attrs):
    """Bazel cc_flags_supplier rule.

    Args:
      **attrs: Rule attributes
    """
    _cc_flags_supplier(**_add_tags(attrs))

def compiler_flag(**attrs):
    """Bazel compiler_flag rule.

    Args:
      **attrs: Rule attributes
    """
    _compiler_flag(**_add_tags(attrs))

cc_common = native_cc_common

CcInfo = NativeCcInfo

CcToolchainConfigInfo = NativeCcToolchainConfigInfo

DebugPackageInfo = NativeDebugPackageInfo
