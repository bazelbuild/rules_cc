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
"""Functions for shared library symlinks."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("//cc/common:cc_helper_internal.bzl", "escape_path", "root_relative_path")

def dynamic_library_soname(library, preserve_name):
    """Returns the SONAME for a dynamic library.

    Args:
        library: The dynamic library output.
        preserve_name: Whether to preserve the output basename.

    Returns:
        The dynamic library SONAME.
    """
    if preserve_name:
        return library.basename

    configuration_mnemonic = paths.basename(paths.dirname(library.root.path))
    transition_index = configuration_mnemonic.find("ST-")
    mnemonic_mangling = ""
    if transition_index != -1:
        mnemonic_mangling = configuration_mnemonic[transition_index:] + "_"
    return "lib" + mnemonic_mangling + escape_path(root_relative_path(library))
