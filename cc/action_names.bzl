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
"""Constants for action names used for C++ rules."""

# Name for the C compilation action.
C_COMPILE_ACTION_NAME = "c-compile"

# Name of the C++ compilation action.
CPP_COMPILE_ACTION_NAME = "c++-compile"

# Name of the linkstamp-compile action.
LINKSTAMP_COMPILE_ACTION_NAME = "linkstamp-compile"

# Name of the action used to compute CC_FLAGS make variable.
CC_FLAGS_MAKE_VARIABLE_ACTION_NAME = "cc-flags-make-variable"

# Name of the C++ module codegen action.
CPP_MODULE_CODEGEN_ACTION_NAME = "c++-module-codegen"

# Name of the C++ header parsing action.
CPP_HEADER_PARSING_ACTION_NAME = "c++-header-parsing"

# Name of the C++ module compile action.
CPP_MODULE_COMPILE_ACTION_NAME = "c++-module-compile"

# Name of the assembler action.
ASSEMBLE_ACTION_NAME = "assemble"

# Name of the assembly preprocessing action.
PREPROCESS_ASSEMBLE_ACTION_NAME = "preprocess-assemble"

# Name of the action producing ThinLto index.
LTO_INDEXING_ACTION_NAME = "lto-indexing"

# Name of the action producing ThinLto index for executable.
LTO_INDEX_FOR_EXECUTABLE_ACTION_NAME = "lto-index-for-executable"

# Name of the action producing ThinLto index for dynamic library.
LTO_INDEX_FOR_DYNAMIC_LIBRARY_ACTION_NAME = "lto-index-for-dynamic-library"

# Name of the action producing ThinLto index for nodeps dynamic library.
LTO_INDEX_FOR_NODEPS_DYNAMIC_LIBRARY_ACTION_NAME = "lto-index-for-nodeps-dynamic-library"

# Name of the action compiling lto bitcodes into native objects.
LTO_BACKEND_ACTION_NAME = "lto-backend"

# Name of the link action producing executable binary.
CPP_LINK_EXECUTABLE_ACTION_NAME = "c++-link-executable"

# Name of the link action producing dynamic library.
CPP_LINK_DYNAMIC_LIBRARY_ACTION_NAME = "c++-link-dynamic-library"

# Name of the link action producing dynamic library that doesn't include it's
# transitive dependencies.
CPP_LINK_NODEPS_DYNAMIC_LIBRARY_ACTION_NAME = "c++-link-nodeps-dynamic-library"

# Name of the archiving action producing static library.
CPP_LINK_STATIC_LIBRARY_ACTION_NAME = "c++-link-static-library"

# Name of the action stripping the binary.
STRIP_ACTION_NAME = "strip"

# A string constant for the objc archive action.
OBJC_ARCHIVE_ACTION_NAME = "objc-archive"

# A string constant for the objc compilation action.
OBJC_COMPILE_ACTION_NAME = "objc-compile"

# A string constant for the objc++ compile action.
OBJCPP_COMPILE_ACTION_NAME = "objc++-compile"

# A string constant for the objc executable link action.
OBJC_EXECUTABLE_ACTION_NAME = "objc-executable"

# A string constant for the objc++ executable link action.
OBJCPP_EXECUTABLE_ACTION_NAME = "objc++-executable"

# A string constant for the objc fully-link link action.
OBJC_FULLY_LINK_ACTION_NAME = "objc-fully-link"

# A string constant for the clif actions.
CLIF_MATCH_ACTION_NAME = "clif-match"

ACTION_NAMES = struct(
    c_compile = C_COMPILE_ACTION_NAME,
    cpp_compile = CPP_COMPILE_ACTION_NAME,
    linkstamp_compile = LINKSTAMP_COMPILE_ACTION_NAME,
    cc_flags_make_variable = CC_FLAGS_MAKE_VARIABLE_ACTION_NAME,
    cpp_module_codegen = CPP_MODULE_CODEGEN_ACTION_NAME,
    cpp_header_parsing = CPP_HEADER_PARSING_ACTION_NAME,
    cpp_module_compile = CPP_MODULE_COMPILE_ACTION_NAME,
    assemble = ASSEMBLE_ACTION_NAME,
    preprocess_assemble = PREPROCESS_ASSEMBLE_ACTION_NAME,
    lto_indexing = LTO_INDEXING_ACTION_NAME,
    lto_backend = LTO_BACKEND_ACTION_NAME,
    lto_index_for_executable = LTO_INDEX_FOR_EXECUTABLE_ACTION_NAME,
    lto_index_for_dynamic_library = LTO_INDEX_FOR_DYNAMIC_LIBRARY_ACTION_NAME,
    lto_index_for_nodeps_dynamic_library = LTO_INDEX_FOR_NODEPS_DYNAMIC_LIBRARY_ACTION_NAME,
    cpp_link_executable = CPP_LINK_EXECUTABLE_ACTION_NAME,
    cpp_link_dynamic_library = CPP_LINK_DYNAMIC_LIBRARY_ACTION_NAME,
    cpp_link_nodeps_dynamic_library = CPP_LINK_NODEPS_DYNAMIC_LIBRARY_ACTION_NAME,
    cpp_link_static_library = CPP_LINK_STATIC_LIBRARY_ACTION_NAME,
    strip = STRIP_ACTION_NAME,
    objc_archive = OBJC_ARCHIVE_ACTION_NAME,
    objc_compile = OBJC_COMPILE_ACTION_NAME,
    objc_executable = OBJC_EXECUTABLE_ACTION_NAME,
    objc_fully_link = OBJC_FULLY_LINK_ACTION_NAME,
    objcpp_compile = OBJCPP_COMPILE_ACTION_NAME,
    objcpp_executable = OBJCPP_EXECUTABLE_ACTION_NAME,
    clif_match = CLIF_MATCH_ACTION_NAME,
)
