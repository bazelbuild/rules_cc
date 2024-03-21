# Copyright 2024 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Implementation of the cc_toolchain rule."""

load("//cc:defs.bzl", _cc_toolchain = "cc_toolchain")
load(
    "//cc/toolchains/impl:toolchain_config.bzl",
    "cc_legacy_file_group",
    "cc_toolchain_config",
)

visibility("public")

# Taken from https://bazel.build/docs/cc-toolchain-config-reference#actions
# TODO: This is best-effort. Update this with the correct file groups once we
#  work out what actions correspond to what file groups.
_LEGACY_FILE_GROUPS = {
    "ar_files": [
        "@rules_cc//cc/toolchains/actions:ar_actions",  # copybara-use-repo-external-label
    ],
    "as_files": [
        "@rules_cc//cc/toolchains/actions:assembly_actions",  # copybara-use-repo-external-label
    ],
    "compiler_files": [
        "@rules_cc//cc/toolchains/actions:cc_flags_make_variable",  # copybara-use-repo-external-label
        "@rules_cc//cc/toolchains/actions:c_compile",  # copybara-use-repo-external-label
        "@rules_cc//cc/toolchains/actions:cpp_compile",  # copybara-use-repo-external-label
        "@rules_cc//cc/toolchains/actions:cpp_header_parsing",  # copybara-use-repo-external-label
    ],
    # There are no actions listed for coverage, dwp, and objcopy in action_names.bzl.
    "coverage_files": [],
    "dwp_files": [],
    "linker_files": [
        "@rules_cc//cc/toolchains/actions:cpp_link_dynamic_library",  # copybara-use-repo-external-label
        "@rules_cc//cc/toolchains/actions:cpp_link_nodeps_dynamic_library",  # copybara-use-repo-external-label
        "@rules_cc//cc/toolchains/actions:cpp_link_executable",  # copybara-use-repo-external-label
    ],
    "objcopy_files": [],
    "strip_files": [
        "@rules_cc//cc/toolchains/actions:strip",  # copybara-use-repo-external-label
    ],
}

def cc_toolchain(
        name,
        dynamic_runtime_lib = None,
        libc_top = None,
        module_map = None,
        output_licenses = [],
        static_runtime_lib = None,
        supports_header_parsing = False,
        supports_param_files = True,
        target_compatible_with = None,
        exec_compatible_with = None,
        compatible_with = None,
        tags = [],
        visibility = None,
        **kwargs):
    """A macro that invokes native.cc_toolchain under the hood.

    Generated rules:
        {name}: A `cc_toolchain` for this toolchain.
        _{name}_config: A `cc_toolchain_config` for this toolchain.
        _{name}_*_files: Generated rules that group together files for
            "ar_files", "as_files", "compiler_files", "coverage_files",
            "dwp_files", "linker_files", "objcopy_files", and "strip_files"
            normally enumerated as part of the `cc_toolchain` rule.

    Args:
        name: str: The name of the label for the toolchain.
        dynamic_runtime_lib: See cc_toolchain.dynamic_runtime_lib
        libc_top: See cc_toolchain.libc_top
        module_map: See cc_toolchain.module_map
        output_licenses: See cc_toolchain.output_licenses
        static_runtime_lib: See cc_toolchain.static_runtime_lib
        supports_header_parsing: See cc_toolchain.supports_header_parsing
        supports_param_files: See cc_toolchain.supports_param_files
        target_compatible_with: target_compatible_with to apply to all generated
          rules
        exec_compatible_with: exec_compatible_with to apply to all generated
          rules
        compatible_with: compatible_with to apply to all generated rules
        tags: Tags to apply to all generated rules
        visibility: Visibility of toolchain rule
        **kwargs: Args to be passed through to cc_toolchain_config.
    """
    all_kwargs = {
        "compatible_with": compatible_with,
        "exec_compatible_with": exec_compatible_with,
        "tags": tags,
        "target_compatible_with": target_compatible_with,
    }
    for group in _LEGACY_FILE_GROUPS:
        if group in kwargs:
            fail("Don't use legacy file groups such as %s. Instead, associate files with tools, actions, and args." % group)

    config_name = "_{}_config".format(name)
    cc_toolchain_config(
        name = config_name,
        visibility = ["//visibility:private"],
        **(all_kwargs | kwargs)
    )

    # Provides ar_files, compiler_files, linker_files, ...
    legacy_file_groups = {}
    for group, actions in _LEGACY_FILE_GROUPS.items():
        group_name = "_{}_{}".format(name, group)
        cc_legacy_file_group(
            name = group_name,
            config = config_name,
            actions = actions,
            visibility = ["//visibility:private"],
            **all_kwargs
        )
        legacy_file_groups[group] = group_name

    if visibility != None:
        all_kwargs["visibility"] = visibility

    _cc_toolchain(
        name = name,
        toolchain_config = config_name,
        all_files = config_name,
        dynamic_runtime_lib = dynamic_runtime_lib,
        libc_top = libc_top,
        module_map = module_map,
        output_licenses = output_licenses,
        static_runtime_lib = static_runtime_lib,
        supports_header_parsing = supports_header_parsing,
        supports_param_files = supports_param_files,
        **(all_kwargs | legacy_file_groups)
    )
