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
"""Helper functions for creating solib and dynamic library symbolic links."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("//cc/common:cc_helper_internal.bzl", "extensions", "is_versioned_shared_library_extension_valid", "root_relative_path")
load("//cc/private:cc_internal.bzl", _cc_internal = "cc_internal")

# TODO(bgorshenev): Remove this variable once we're sure these functions won't
# won't interfere with path mapping.
USE_STARLARK_SOLIB_SYMLINK = True

def _escaped_path(path):
    return path.replace("_", "_U").replace("/", "_S").replace("\\", "_B").replace(":", "_C").replace("@", "_A")

def _label_to_string(label):
    """Java and Starlark convert label to string slightly differently. Match Java's behavior."""
    s = str(label)
    if s.startswith("@@//"):  # buildifier: disable=canonical-repository
        return s[2:]
    if s.startswith("@//"):
        return s[1:]
    return s

def _is_shared_library_filetype(basename):
    if "." not in basename:
        return True
    if is_versioned_shared_library_extension_valid(basename):
        return True
    ext = basename[basename.rfind("."):]
    if ext in extensions.SHARED_LIBRARY:
        return True
    if ext in extensions.INTERFACE_SHARED_LIBRARY:
        return True
    return False

def _dynamic_library_soname(library_path, preserve_name, mnemonic):
    if preserve_name:
        return paths.basename(library_path)
    else:
        mnemonic_mangling = ""
        if "ST-" in mnemonic:
            st_index = mnemonic.find("ST-")
            mnemonic_mangling = mnemonic[st_index:] + "_"
        return "lib" + mnemonic_mangling + _escaped_path(library_path)

def dynamic_library_soname(actions, library_path, preserve_name):
    """Compute the SONAME to use for a dynamic library.

    This name is basically the name of the shared
    library in its final symlinked location.

    Args:
        actions: action construction context of rule requesting symlink
        library_path: name of the shared library that needs to be mangled
        preserve_name: whether to preserve the name of the library

    Returns:
        soname to embed in the dynamic library
    """
    if USE_STARLARK_SOLIB_SYMLINK and hasattr(_cc_internal, "maybe_hash_preserve_extension"):
        ctx = _cc_internal.actions2ctx_cheat(actions)
        mnemonic = ctx.bin_dir.path.split("/")[1]
        return _dynamic_library_soname(library_path, preserve_name, mnemonic)
    else:
        return _cc_internal.dynamic_library_soname(actions, library_path, preserve_name)

def _get_mangled_name(label, solib_dir, mnemonic, library_path, preserve_name, prefix_consumer):
    escaped_rule_path = _escaped_path("_" + _label_to_string(label))
    soname = _dynamic_library_soname(library_path, preserve_name, mnemonic)

    if preserve_name:
        parent_dir = paths.dirname(library_path)
        escaped_library_path = _escaped_path("_" + parent_dir)
        escaped_full_path = escaped_rule_path + "__" + escaped_library_path if prefix_consumer else escaped_library_path
        mangled_dir = solib_dir + "/" + _cc_internal.maybe_hash_preserve_extension(escaped_full_path)
        return mangled_dir + "/" + soname
    else:
        filename = escaped_rule_path + "__" + soname if prefix_consumer else soname
        return solib_dir + "/" + _cc_internal.maybe_hash_preserve_extension(filename)

def dynamic_library_symlink(actions, library, solib_directory, preserve_name, prefix_consumer):
    """ Create dynamic library symlink.

    Replaces shared library artifact with mangled symlink and creates related symlink action. For
    artifacts that should retain filename (e.g. libraries with SONAME tag), link is created to the
    parent directory instead.

    This action is performed to minimize number of -rpath entries used during linking process
    (by essentially "collecting" as many shared libraries as possible in the single directory),
    since we will be paying quadratic price for each additional entry on the -rpath.

    Args:
        actions: action construction context of rule requesting symlink
        library: Shared library artifact that needs to be mangled.
        solib_directory: String giving the solib directory
        preserve_name: whether to preserve the name of the library
        prefix_consumer: whether to prefix the output artifact name with the label of the consumer
    Returns:
        mangled symlink artifact.
   """
    if USE_STARLARK_SOLIB_SYMLINK and hasattr(_cc_internal, "maybe_hash_preserve_extension"):
        if not _is_shared_library_filetype(library.basename):
            fail("Library '%s' does not match expected filetype" % library.basename)
        if root_relative_path(library).startswith("_solib_"):
            fail("Library '%s' is already in _solib_" % library.path)
        ctx = _cc_internal.actions2ctx_cheat(actions)
        label = ctx.label
        mnemonic = ctx.bin_dir.path.split("/")[1]
        mangled_name = _get_mangled_name(
            label,
            solib_directory,
            mnemonic,
            root_relative_path(library),
            preserve_name,
            prefix_consumer,
        )
        symlink = ctx.actions.declare_shareable_artifact(mangled_name)
        ctx.actions.symlink(
            output = symlink,
            target_file = library,
        )
        return symlink
    else:
        return _cc_internal.dynamic_library_symlink(actions, library, solib_directory, preserve_name, prefix_consumer)

def dynamic_library_symlink2(actions, library, solib_directory, path):
    """Creates a symlink for a dynamic library with a rule-specified path.

    Args:
        actions: action construction context of rule requesting symlink
        library: Shared library artifact
        solib_directory: String giving the solib directory
        path: Symlink path underneath the solib directory.
    Returns:
        symlink artifact.
    """
    if USE_STARLARK_SOLIB_SYMLINK and hasattr(_cc_internal, "maybe_hash_preserve_extension"):
        if not _is_shared_library_filetype(library.basename):
            fail("Library '%s' does not match expected filetype" % library.basename)
        if not _is_shared_library_filetype(path.split("/")[-1]):
            fail("Path '%s' does not match expected filetype" % path)
        if root_relative_path(library).startswith("_solib_"):
            fail("Library '%s' is already in _solib_" % library.path)
        ctx = _cc_internal.actions2ctx_cheat(actions)
        symlink_name = solib_directory + "/" + path
        symlink = ctx.actions.declare_shareable_artifact(symlink_name)
        ctx.actions.symlink(
            output = symlink,
            target_file = library,
        )
        return symlink
    else:
        return _cc_internal.dynamic_library_symlink2(actions, library, solib_directory, path)

def solib_symlink_action(ctx, artifact, solib_directory, runtime_solib_dir_base):
    """Create a symlink for C++ runtime libraries without name or directory mangling.

    Args:
        ctx: rule context of rule requesting symlink
        artifact: Shared library artifact
        solib_directory: String giving the solib directory, as defined by the toolchain.
        runtime_solib_dir_base: Base directory for runtime symlinks, if the toolchain's needs to be overridden.
    Returns:
        symlink artifact.
    """
    if USE_STARLARK_SOLIB_SYMLINK:
        if not _is_shared_library_filetype(artifact.basename):
            fail("Library '%s' does not match expected filetype" % artifact.basename)
        if root_relative_path(artifact).startswith("_solib_"):
            fail("Library '%s' is already in _solib_" % artifact.path)
        solib_dir = runtime_solib_dir_base if runtime_solib_dir_base != None else solib_directory
        symlink_name = solib_dir + "/" + artifact.basename
        symlink = ctx.actions.declare_shareable_artifact(symlink_name)
        ctx.actions.symlink(
            output = symlink,
            target_file = artifact,
        )
        return symlink
    else:
        return _cc_internal.solib_symlink_action(ctx, artifact, solib_directory, runtime_solib_dir_base)
