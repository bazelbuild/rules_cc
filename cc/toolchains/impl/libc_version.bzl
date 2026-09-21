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

"""Helper function for parsing target_libc values."""

visibility([
    "//cc/toolchains",
    "//tests/libc_settings",
])

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
