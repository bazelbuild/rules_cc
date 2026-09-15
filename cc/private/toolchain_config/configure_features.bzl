# Copyright 2025 The Bazel Authors. All rights reserved.
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
"""Helper functions for C++ feature configuration."""

load("//cc:action_names.bzl", "ACTION_NAMES")
load("//cc/common:feature_names.bzl", "feature_names")
load("//cc/common:semantics.bzl", cc_semantics = "semantics")

ALL_COMPILE_ACTIONS = [
    ACTION_NAMES.c_compile,
    ACTION_NAMES.cpp_compile,
    ACTION_NAMES.cpp_header_parsing,
    ACTION_NAMES.cpp_module_compile,
    ACTION_NAMES.cpp_module_codegen,
    ACTION_NAMES.cpp_module_deps_scanning,
    ACTION_NAMES.cpp20_module_compile,
    ACTION_NAMES.cpp20_module_codegen,
    ACTION_NAMES.assemble,
    ACTION_NAMES.preprocess_assemble,
    ACTION_NAMES.clif_match,
    ACTION_NAMES.linkstamp_compile,
    ACTION_NAMES.cc_flags_make_variable,
    ACTION_NAMES.lto_backend,
    ACTION_NAMES.cpp_header_analysis,
]

ALL_LINK_ACTIONS = [
    ACTION_NAMES.lto_index_for_executable,
    ACTION_NAMES.lto_index_for_dynamic_library,
    ACTION_NAMES.lto_index_for_nodeps_dynamic_library,
    ACTION_NAMES.cpp_link_executable,
    ACTION_NAMES.cpp_link_dynamic_library,
    ACTION_NAMES.cpp_link_nodeps_dynamic_library,
]

ALL_ARCHIVE_ACTIONS = [
    ACTION_NAMES.cpp_link_static_library,
]

ALL_OTHER_ACTIONS = [
    ACTION_NAMES.strip,
]

DEFAULT_ACTION_CONFIGS = ALL_COMPILE_ACTIONS + ALL_LINK_ACTIONS + ALL_ARCHIVE_ACTIONS + ALL_OTHER_ACTIONS

OBJC_ACTIONS = [
    ACTION_NAMES.objc_compile,
    ACTION_NAMES.objcpp_compile,
    ACTION_NAMES.objc_fully_link,
    ACTION_NAMES.objc_executable,
]

def _get_coverage_features(cpp_configuration):
    coverage_features = []
    coverage_features.append("coverage")
    if cpp_configuration.use_llvm_coverage_map_format():
        coverage_features.append("llvm_coverage_map_format")
    else:
        coverage_features.append("gcc_coverage_map_format")
    return coverage_features

def configure_features(
        *,
        ctx,
        cc_toolchain,
        language = "c++",
        requested_features = [],
        unsupported_features = []):
    """Creates a feature_configuration instance. Requires the cpp configuration fragment.

    Args:
      ctx: (RuleContext) The rule context.
      cc_toolchain: (CcToolchainInfo) cc_toolchain for which we configure features.
      language: ("c++"|"objc"|""objc++") The language to configure for. (default c++)
      requested_features: (list[str]) List of features to be enabled.
      unsupported_features: (list[str]) List of features that are unsupported by the current rule.

    Returns:
      (FeatureConfiguration) The feature configuration.
    """

    language = (language or "c++").replace("+", "p")

    # TODO(b/236152224): Remove the following when all Starlark objc configure_features have the
    # chance to migrate to using the language parameter.
    if "lang_objc" in requested_features:
        language = "objc"

    if not hasattr(ctx.fragments, "cpp"):
        fail("cpp configuration fragment is missing")

    cpp_configuration = ctx.fragments.cpp

    if language == "cpp":
        cc_semantics.validate_layering_check_features(
            ctx = ctx,
            cc_toolchain = cc_toolchain,
            unsupported_features = unsupported_features,
        )

    all_requested_features_set = set()
    all_unsupported_features_set = set(unsupported_features)

    if not cc_toolchain._supports_header_parsing:
        # TODO(b/159096411): Remove once supports_header_parsing has been removed from the
        # cc_toolchain rule.
        all_unsupported_features_set.add(feature_names.PARSE_HEADERS)

    if (language != "objc" and
        language != "objcpp" and
        cc_toolchain._cc_info.compilation_context._module_map == None):
        all_unsupported_features_set.add(feature_names.MODULE_MAPS)

    if cpp_configuration.force_pic():
        if feature_names.SUPPORTS_PIC in all_unsupported_features_set:
            fail("PIC compilation is requested but the toolchain does not support it " +
                 "(feature named '{}' is not enabled)".format(feature_names.SUPPORTS_PIC))
        all_requested_features_set.add(feature_names.SUPPORTS_PIC)

    if cpp_configuration.apple_generate_dsym:
        all_requested_features_set.add(feature_names.GENERATE_DSYM_FILE)
    else:
        all_requested_features_set.add(feature_names.NO_GENERATE_DEBUG_SYMBOLS)

    if language == "objc" or language == "objcpp":
        all_requested_features_set.add("lang_objc")
        if cpp_configuration.objc_generate_linkmap:
            all_requested_features_set.add(feature_names.GENERATE_LINKMAP)
        if cpp_configuration.objc_should_strip_binary:
            all_requested_features_set.add(feature_names.DEAD_STRIP)

    all_features = [cpp_configuration.compilation_mode()]
    all_features.extend(DEFAULT_ACTION_CONFIGS)
    all_features.extend(requested_features)
    all_features.extend(cc_toolchain._default_features_and_action_configs)

    if language == "objc" or language == "objcpp":
        all_features.extend(OBJC_ACTIONS)

    if not cpp_configuration._dont_enable_host_nonhost:
        if cc_toolchain._is_tool_configuration:
            all_features.append("host")
        else:
            all_features.append("nonhost")

    if ctx.configuration.is_tool_configuration():
        all_features.append("exec_cfg")
    else:
        all_features.append("non_exec_cfg")

    if ctx.configuration.coverage_enabled:
        all_features.extend(_get_coverage_features(cpp_configuration))

    if feature_names.FDO_INSTRUMENT not in all_unsupported_features_set:
        if cpp_configuration.fdo_instrument() != None:
            all_features.append(feature_names.FDO_INSTRUMENT)
        elif cpp_configuration.cs_fdo_instrument() != None:
            all_features.append(feature_names.CS_FDO_INSTRUMENT)

    fdo_context = cc_toolchain._fdo_context
    branch_fdo_provider = getattr(fdo_context, "branch_fdo_profile", None)

    enable_propeller_optimize = (
        getattr(fdo_context, "propeller_optimize_info", None) != None and
        (fdo_context.propeller_optimize_info.cc_profile != None or
         fdo_context.propeller_optimize_info.ld_profile != None)
    )

    if branch_fdo_provider != None and cpp_configuration.compilation_mode() == "opt":
        if ((branch_fdo_provider.branch_fdo_mode == "llvm_fdo" or
             branch_fdo_provider.branch_fdo_mode == "llvm_cs_fdo") and
            feature_names.FDO_OPTIMIZE not in all_unsupported_features_set):
            all_features.append(feature_names.FDO_OPTIMIZE)
            if feature_names.MEMPROF_OPTIMIZE not in all_unsupported_features_set:
                all_features.append(feature_names.ENABLE_FDO_MEMPROF_OPTIMIZE)
            if feature_names.THIN_LTO not in all_unsupported_features_set:
                all_features.append(feature_names.ENABLE_FDO_THINLTO)
            if (feature_names.SPLIT_FUNCTIONS not in all_unsupported_features_set and
                not enable_propeller_optimize):
                all_features.append(feature_names.ENABLE_FDO_SPLIT_FUNCTIONS)

        if branch_fdo_provider.branch_fdo_mode == "llvm_cs_fdo":
            all_features.append(feature_names.CS_FDO_OPTIMIZE)

        if branch_fdo_provider.branch_fdo_mode == "auto_fdo":
            all_features.append(feature_names.AUTOFDO)
            if feature_names.MEMPROF_OPTIMIZE not in all_unsupported_features_set:
                all_features.append(feature_names.ENABLE_AUTOFDO_MEMPROF_OPTIMIZE)
            if feature_names.THIN_LTO not in all_unsupported_features_set:
                all_features.append(feature_names.ENABLE_AFDO_THINLTO)
            if feature_names.FSAFDO not in all_unsupported_features_set:
                all_features.append(feature_names.ENABLE_FSAFDO)
                if feature_names.SPLIT_FUNCTIONS not in all_unsupported_features_set:
                    all_features.append(feature_names.ENABLE_FDO_SPLIT_FUNCTIONS)

        if branch_fdo_provider.branch_fdo_mode == "xbinary_fdo":
            all_features.append(feature_names.XBINARYFDO)
            if feature_names.THIN_LTO not in all_unsupported_features_set:
                all_features.append(feature_names.ENABLE_XBINARYFDO_THINLTO)

    if cpp_configuration._fdo_prefetch_hints_label != None:
        all_features.append(feature_names.FDO_PREFETCH_HINTS)

    if enable_propeller_optimize:
        all_features.append(feature_names.PROPELLER_OPTIMIZE)

    for feature in all_features:
        if feature not in all_unsupported_features_set:
            all_requested_features_set.add(feature)

    feature_configuration = cc_toolchain._toolchain_features.configure_features(
        requested_features = list(all_requested_features_set),
    )

    for feature in all_unsupported_features_set:
        if feature_configuration.is_enabled(feature):
            fail(("The C++ toolchain '{}' unconditionally implies feature '{}', which is unsupported " +
                  "by this rule. This is most likely a misconfiguration in the C++ toolchain.")
                .format(cc_toolchain._toolchain_label, feature))

    if (cpp_configuration.force_pic() and
        not feature_configuration.is_enabled(feature_names.PIC) and
        not feature_configuration.is_enabled(feature_names.SUPPORTS_PIC)):
        fail("PIC compilation is requested but the toolchain does not support it " +
             "(feature named '{}' is not enabled)".format(feature_names.SUPPORTS_PIC))

    return feature_configuration
