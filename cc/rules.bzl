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

def cc_binary(**attrs):
    """Bazel cc_binary rule.

    https://docs.bazel.build/versions/master/be/c-cpp.html#cc_binary

    Args:
      **attrs: Rule attributes
    """
    native.cc_binary(**attrs)

def cc_test(**attrs):
    """Bazel cc_test rule.

    https://docs.bazel.build/versions/master/be/c-cpp.html#cc_test

    Args:
      **attrs: Rule attributes
    """
    native.cc_test(**attrs)

def cc_library(**attrs):
    """Bazel cc_library rule.

    https://docs.bazel.build/versions/master/be/c-cpp.html#cc_library

    Args:
      **attrs: Rule attributes
    """
    native.cc_library(**attrs)

def cc_import(**attrs):
    """Bazel cc_import rule.

    https://docs.bazel.build/versions/master/be/c-cpp.html#cc_import

    Args:
      **attrs: Rule attributes
    """
    native.cc_import(**attrs)

def cc_proto_library(**attrs):
    """Bazel cc_proto_library rule.

    https://docs.bazel.build/versions/master/be/c-cpp.html#cc_proto_library

    Args:
      **attrs: Rule attributes
    """
    native.cc_proto_library(**attrs)

def fdo_prefetch_hints(**attrs):
    """Bazel fdo_prefetch_hints rule.

    https://docs.bazel.build/versions/master/be/c-cpp.html#fdo_prefetch_hints

    Args:
      **attrs: Rule attributes
    """
    native.fdo_prefetch_hints(**attrs)

def fdo_profile(**attrs):
    """Bazel fdo_profile rule.

    https://docs.bazel.build/versions/master/be/c-cpp.html#fdo_profile

    Args:
      **attrs: Rule attributes
    """
    native.fdo_profile(**attrs)
