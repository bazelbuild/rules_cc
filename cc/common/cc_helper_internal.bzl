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

"""
Utility functions for C++ rules that don't depend on cc_common.

Only use those within C++ implementation. The others need to go through cc_common.
"""

load("@bazel_skylib//lib:paths.bzl", "paths")

# LINT.IfChange(forked_exports)

def is_versioned_shared_library_extension_valid(shared_library_name):
    """Validates the name against the regex "^.+\\.((so)|(dylib))(\\.\\d\\w*)+$",

    Args:
        shared_library_name: (str) the name to validate

    Returns:
        (bool)
    """

    # must match VERSIONED_SHARED_LIBRARY.
    for ext in (".so.", ".dylib."):
        name, _, version = shared_library_name.rpartition(ext)
        if name and version:
            version_parts = version.split(".")
            for part in version_parts:
                if not part[0].isdigit():
                    return False
                for c in part[1:].elems():
                    if not (c.isalnum() or c == "_"):
                        return False
            return True
    return False

def _is_repository_main(repository):
    return repository == ""

def package_source_root(repository, package, sibling_repository_layout):
    """
    Determines the source root for a given repository and package.

    Args:
      repository: The repository to get the source root for.
      package: The package to get the source root for.
      sibling_repository_layout: Whether the repository layout is a sibling repository layout.

    Returns:
      The source root for the given repository and package.
    """
    if _is_repository_main(repository) or sibling_repository_layout:
        return package
    if repository.startswith("@"):
        repository = repository[1:]
    return paths.get_relative(paths.get_relative("external", repository), package)

def repository_exec_path(repository, sibling_repository_layout):
    """
    Determines the exec path for a given repository.

    Args:
      repository: The repository to get the exec path for.
      sibling_repository_layout: Whether the repository layout is a sibling repository layout.

    Returns:
      The exec path for the given repository.
    """
    if _is_repository_main(repository):
        return ""
    prefix = "external"
    if sibling_repository_layout:
        prefix = ".."
    if repository.startswith("@"):
        repository = repository[1:]
    return paths.get_relative(prefix, repository)

# LINT.ThenChange(https://github.com/bazelbuild/bazel/blob/master/src/main/starlark/builtins_bzl/common/cc/cc_helper_internal.bzl:forked_exports)

def get_relative_path(path_a, path_b):
    if paths.is_absolute(path_b):
        return path_b
    return paths.normalize(paths.join(path_a, path_b))

def path_contains_up_level_references(path):
    return path.startswith("..") and (len(path) == 2 or path[2] == "/")
