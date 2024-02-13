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
load("//cc:action_names.bzl", "ACTION_NAMES")
load("//cc/toolchains:actions.bzl", "cc_action_type", "cc_action_type_set")

package(default_visibility = ["//visibility:public"])

# Keep in sync with //cc:action_names.bzl.

cc_action_type(
    name = "c_compile",
    action_name = ACTION_NAMES.c_compile,
)

cc_action_type(
    name = "cpp_compile",
    action_name = ACTION_NAMES.cpp_compile,
)

cc_action_type(
    name = "linkstamp_compile",
    action_name = ACTION_NAMES.linkstamp_compile,
)

cc_action_type(
    name = "cc_flags_make_variable",
    action_name = ACTION_NAMES.cc_flags_make_variable,
)

cc_action_type(
    name = "cpp_module_codegen",
    action_name = ACTION_NAMES.cpp_module_codegen,
)

cc_action_type(
    name = "cpp_header_parsing",
    action_name = ACTION_NAMES.cpp_header_parsing,
)

cc_action_type(
    name = "cpp_module_compile",
    action_name = ACTION_NAMES.cpp_module_compile,
)

cc_action_type(
    name = "assemble",
    action_name = ACTION_NAMES.assemble,
)

cc_action_type(
    name = "preprocess_assemble",
    action_name = ACTION_NAMES.preprocess_assemble,
)

cc_action_type(
    name = "lto_indexing",
    action_name = ACTION_NAMES.lto_indexing,
)

cc_action_type(
    name = "lto_backend",
    action_name = ACTION_NAMES.lto_backend,
)

cc_action_type(
    name = "lto_index_for_executable",
    action_name = ACTION_NAMES.lto_index_for_executable,
)

cc_action_type(
    name = "lto_index_for_dynamic_library",
    action_name = ACTION_NAMES.lto_index_for_dynamic_library,
)

cc_action_type(
    name = "lto_index_for_nodeps_dynamic_library",
    action_name = ACTION_NAMES.lto_index_for_nodeps_dynamic_library,
)

cc_action_type(
    name = "cpp_link_executable",
    action_name = ACTION_NAMES.cpp_link_executable,
)

cc_action_type(
    name = "cpp_link_dynamic_library",
    action_name = ACTION_NAMES.cpp_link_dynamic_library,
)

cc_action_type(
    name = "cpp_link_nodeps_dynamic_library",
    action_name = ACTION_NAMES.cpp_link_nodeps_dynamic_library,
)

cc_action_type(
    name = "cpp_link_static_library",
    action_name = ACTION_NAMES.cpp_link_static_library,
)

cc_action_type(
    name = "strip",
    action_name = ACTION_NAMES.strip,
)

cc_action_type(
    name = "objc_compile",
    action_name = ACTION_NAMES.objc_compile,
)

cc_action_type(
    name = "objc_executable",
    action_name = ACTION_NAMES.objc_executable,
)

cc_action_type(
    name = "objc_fully_link",
    action_name = ACTION_NAMES.objc_fully_link,
)

cc_action_type(
    name = "objcpp_compile",
    action_name = ACTION_NAMES.objcpp_compile,
)

cc_action_type(
    name = "clif_match",
    action_name = ACTION_NAMES.clif_match,
)

cc_action_type_set(
    name = "all_cpp_compile_actions",
    actions = [
        ":linkstamp_compile",
        ":cpp_compile",
        ":cpp_header_parsing",
        ":cpp_module_compile",
        ":cpp_module_codegen",
        ":lto_backend",
        ":clif_match",
    ],
)

cc_action_type_set(
    name = "all_cc_compile_actions",
    actions = [
        ":all_cpp_compile_actions",
        ":c_compile",
        ":preprocess_assemble",
        ":assemble",
    ],
)

cc_action_type_set(
    name = "all_cc_link_actions",
    actions = [
        ":cpp_link_executable",
        ":cpp_link_dynamic_library",
        ":cpp_link_nodeps_dynamic_library",
        ":lto_index_for_executable",
        ":lto_index_for_dynamic_library",
        ":lto_index_for_nodeps_dynamic_library",
    ],
)

cc_action_type_set(
    name = "cc_link_executable_actions",
    actions = [
        ":cpp_link_executable",
        ":lto_index_for_executable",
    ],
)

cc_action_type_set(
    name = "dynamic_library_link_actions",
    actions = [
        ":cpp_link_dynamic_library",
        ":cpp_link_nodeps_dynamic_library",
        ":lto_index_for_dynamic_library",
        ":lto_index_for_nodeps_dynamic_library",
    ],
)

cc_action_type_set(
    name = "nodeps_dynamic_library_link_actions",
    actions = [
        ":cpp_link_nodeps_dynamic_library",
        ":lto_index_for_nodeps_dynamic_library",
    ],
)

cc_action_type_set(
    name = "transitive_link_actions",
    actions = [
        ":cpp_link_executable",
        ":cpp_link_dynamic_library",
        ":lto_index_for_executable",
        ":lto_index_for_dynamic_library",
    ],
)

cc_action_type_set(
    name = "all_actions",
    actions = [
        ":c_compile",
        ":cpp_compile",
        ":linkstamp_compile",
        ":cc_flags_make_variable",
        ":cpp_module_codegen",
        ":cpp_header_parsing",
        ":cpp_module_compile",
        ":assemble",
        ":preprocess_assemble",
        ":lto_indexing",
        ":lto_backend",
        ":lto_index_for_executable",
        ":lto_index_for_dynamic_library",
        ":lto_index_for_nodeps_dynamic_library",
        ":cpp_link_executable",
        ":cpp_link_dynamic_library",
        ":cpp_link_nodeps_dynamic_library",
        ":cpp_link_static_library",
        ":strip",
        ":objc_compile",
        ":objc_executable",
        ":objc_fully_link",
        ":objcpp_compile",
        ":clif_match",
    ],
)
