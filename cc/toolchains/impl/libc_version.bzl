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

"""Helper functions for parsing target_libc values."""

visibility([
    "//cc/libc",
    "//cc/toolchains",
    "//tests/libc_settings",
])

# The glibc versions with a `glibc_at_least_<version>` config setting in //cc/libc. Extend the range
# when a new version of glibc is released.
GLIBC_VERSIONS = ["2.%d" % minor for minor in range(15, 45)]

def libc_without_version(libc):
    """Strips a version suffix from a target_libc value.

    Args:
        libc: (str) The value of cc_toolchain.libc.

    Returns:
        The name of the C standard library without a version suffix.
    """
    for i in range(1, len(libc) - 1):
        if libc[i] == "-" and libc[i + 1].isdigit():
            return libc[:i]
    return libc

def parse_libc_version(version):
    """Parses the version of a C standard library.

    Args:
        version: (str) A version with two or three numeric components separated by dots (e.g.
            "2.31" or "1.2.4").

    Returns:
        The components of the version as a tuple of integers, or None if the version doesn't have
        this format.
    """
    components = version.split(".")
    if len(components) < 2 or len(components) > 3:
        return None
    for component in components:
        if not component.isdigit() or (len(component) > 1 and component.startswith("0")):
            return None
    return tuple([int(component) for component in components])

def libc_version(libc):
    """Parses the version suffix of a target_libc value.

    Args:
        libc: (str) The value of cc_toolchain.libc.

    Returns:
        The components of the version as a tuple of integers (e.g. (2, 31) for "glibc-2.31"), or
        None if the value doesn't have a version suffix with two or three numeric components.
    """
    name = libc_without_version(libc)
    if name == libc:
        return None
    return parse_libc_version(libc[len(name) + 1:])
