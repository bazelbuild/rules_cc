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
""""Mapping of legacy file groups"""

# Taken from https://bazel.build/docs/cc-toolchain-config-reference#actions
# TODO: This is best-effort. Update this with the correct file groups once we
#  work out what actions correspond to what file groups.
LEGACY_FILE_GROUPS = {
    "ar_files": [
        Label("//cc/toolchains/actions:ar_actions"),
    ],
    "as_files": [
        Label("//cc/toolchains/actions:assembly_actions"),
    ],
    "compiler_files": [
        Label("//cc/toolchains/actions:cc_flags_make_variable"),
        Label("//cc/toolchains/actions:c_compile"),
        Label("//cc/toolchains/actions:cpp_compile"),
        Label("//cc/toolchains/actions:cpp_header_parsing"),
    ],
    # There are no actions listed for coverage and objcopy in action_names.bzl.
    "coverage_files": [],
    "dwp_files": [
        Label("//cc/toolchains/actions:dwp"),
    ],
    "linker_files": [
        Label("//cc/toolchains/actions:cpp_link_dynamic_library"),
        Label("//cc/toolchains/actions:cpp_link_nodeps_dynamic_library"),
        Label("//cc/toolchains/actions:cpp_link_executable"),
    ],
    "objcopy_files": [],
    "strip_files": [
        Label("//cc/toolchains/actions:strip"),
    ],
}
