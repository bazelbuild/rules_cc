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
"""Tree artifact compilation actions"""

load("@bazel_features//:features.bzl", "bazel_features")
load("@bazel_skylib//lib:paths.bzl", "paths")
load(
    "//cc/common:cc_helper_internal.bzl",
    "CPP_SOURCE_TYPE_HEADER",
    "CPP_SOURCE_TYPE_SOURCE",
    "extensions",
    artifact_category = "artifact_category_names",
)
load("//cc/common:feature_names.bzl", "feature_names")
load("//cc/common:semantics.bzl", cc_semantics = "semantics")
load("//cc/private:cc_internal.bzl", _cc_internal = "cc_internal")
load("//cc/private/compile:cc_compilation_helper.bzl", "dotd_files_enabled", "serialized_diagnostics_file_enabled", "use_dotd_file")
load(
    "//cc/private/compile:compile_build_variables.bzl",
    "get_copts",
    "get_specific_compile_build_variables",
    "get_template_added_build_variables",
)

# buildifier: disable=function-docstring
def create_compile_action_templates(
        *,
        action_construction_context,
        cc_compilation_context,
        cc_toolchain,
        configuration,
        cpp_configuration,
        feature_configuration,
        language,
        common_compile_build_variables,
        source_dir,
        source_type,
        source_label,
        label,
        copts,
        conlyopts,
        cxxopts,
        generate_pic_action,
        generate_no_pic_action,
        additional_compilation_inputs,
        additional_include_scanning_roots,
        output_name,
        outputs):
    if source_type not in [CPP_SOURCE_TYPE_SOURCE, CPP_SOURCE_TYPE_HEADER]:
        fail("Encountered invalid source types when creating CppCompileActionTemplates: " + source_type)
    all_copts = get_copts(
        language = language,
        cpp_configuration = cpp_configuration,
        source_file = source_dir,
        conlyopts = conlyopts,
        copts = copts,
        cxxopts = cxxopts,
        label = source_label,
    )

    # Currently we do not generate minimized bitcode files for tree artifacts because of issues
    # with the indexing step.
    # If lto_index_tree_artifact is set to a tree artifact, the minimized bitcode files will be
    # properly generated and will be an input to the indexing step. However, the lto indexing step
    # fails. The indexing step finds the full bitcode file by replacing the suffix of the
    # minimized bitcode file, therefore they have to be in the same directory.
    # Since the files are in the same directory, the command line artifact expander expands the
    # tree artifact to both the minimized bitcode files and the full bitcode files, causing an
    # error that functions are defined twice.
    # TODO(b/289071777): support for minimized bitcode files.
    lto_index_tree_artifact = None

    if source_type == CPP_SOURCE_TYPE_HEADER:
        _create_compile_action_template(
            action_construction_context = action_construction_context,
            cc_compilation_context = cc_compilation_context,
            cc_toolchain = cc_toolchain,
            configuration = configuration,
            feature_configuration = feature_configuration,
            common_compile_build_variables = common_compile_build_variables,
            source_dir = source_dir,
            label = label,
            all_copts = all_copts,
            additional_compilation_inputs = additional_compilation_inputs,
            additional_include_scanning_roots = additional_include_scanning_roots,
            output_name = output_name,
            outputs = outputs,
            lto_output_enabled = False,
            use_pic = generate_pic_action,
            output_categories = [artifact_category.GENERATED_HEADER, artifact_category.PROCESSED_HEADER],
            outputs_key = "header_tokens",
            lto_index_tree_artifact = lto_index_tree_artifact,
            language = language,
        )
    else:  # CPP_SOURCE_TYPE_SOURCE
        lto_output_enabled = feature_configuration.is_enabled(feature_names.THIN_LTO)
        if generate_no_pic_action:
            _create_compile_action_template(
                action_construction_context = action_construction_context,
                cc_compilation_context = cc_compilation_context,
                cc_toolchain = cc_toolchain,
                configuration = configuration,
                feature_configuration = feature_configuration,
                common_compile_build_variables = common_compile_build_variables,
                source_dir = source_dir,
                label = label,
                all_copts = all_copts,
                additional_compilation_inputs = additional_compilation_inputs,
                additional_include_scanning_roots = additional_include_scanning_roots,
                output_name = output_name,
                outputs = outputs,
                lto_output_enabled = lto_output_enabled,
                use_pic = False,
                output_categories = [artifact_category.OBJECT_FILE],
                outputs_key = "objects",
                lto_index_tree_artifact = lto_index_tree_artifact,
                language = language,
            )
        if generate_pic_action:
            _create_compile_action_template(
                action_construction_context = action_construction_context,
                cc_compilation_context = cc_compilation_context,
                cc_toolchain = cc_toolchain,
                configuration = configuration,
                feature_configuration = feature_configuration,
                common_compile_build_variables = common_compile_build_variables,
                source_dir = source_dir,
                label = label,
                all_copts = all_copts,
                additional_compilation_inputs = additional_compilation_inputs,
                additional_include_scanning_roots = additional_include_scanning_roots,
                output_name = output_name,
                outputs = outputs,
                lto_output_enabled = lto_output_enabled,
                use_pic = True,
                output_categories = [artifact_category.PIC_OBJECT_FILE],
                outputs_key = "pic_objects",
                lto_index_tree_artifact = lto_index_tree_artifact,
                language = language,
            )

def _create_compile_action_template(
        *,
        action_construction_context,
        cc_compilation_context,
        cc_toolchain,
        configuration,
        feature_configuration,
        common_compile_build_variables,
        source_dir,
        label,
        all_copts,
        additional_compilation_inputs,
        additional_include_scanning_roots,
        output_name,
        outputs,
        lto_output_enabled,
        use_pic,
        output_categories,
        outputs_key,
        lto_index_tree_artifact,
        language):
    output_dir = _declare_compile_output_tree_artifact(
        action_construction_context,
        label,
        output_name,
        use_pic = use_pic,
    )
    specific_compile_build_variables = get_specific_compile_build_variables(
        use_pic = use_pic,
        source_file = source_dir,
        output_file = output_dir,
        user_compile_flags = all_copts,
    )
    dotd_tree_artifact = _maybe_declare_dotd_tree_artifact(
        action_construction_context,
        feature_configuration,
        language,
        label,
        output_name,
        use_pic = use_pic,
    )
    diagnostics_tree_artifact = _maybe_declare_diagnostics_tree_artifact(
        action_construction_context,
        feature_configuration,
        label,
        output_name,
        use_pic = use_pic,
    )
    if lto_output_enabled:
        outputs["lto_compilation_context"][output_dir] = (lto_index_tree_artifact, all_copts)

    if bazel_features.cc._map_directory_supports_cc_compile:
        _starlark_create_cc_compile_action_template(
            action_construction_context = action_construction_context,
            cc_compilation_context = cc_compilation_context,
            cc_toolchain = cc_toolchain,
            configuration = configuration,
            feature_configuration = feature_configuration,
            compile_build_variables = _cc_internal.combine_cc_toolchain_variables(
                common_compile_build_variables,
                specific_compile_build_variables,
            ),
            source_dir = source_dir,
            additional_compilation_inputs = additional_compilation_inputs,
            additional_include_scanning_roots = additional_include_scanning_roots,
            use_pic = use_pic,
            output_categories = output_categories,
            output_dir = output_dir,
            dotd_tree_artifact = dotd_tree_artifact,
            diagnostics_tree_artifact = diagnostics_tree_artifact,
            lto_indexing_tree_artifact = lto_index_tree_artifact,
            needs_include_validation = cc_semantics.needs_include_validation(language),
            toolchain_type = cc_semantics.toolchain,
        )
    else:
        _cc_internal.create_cc_compile_action_template(
            action_construction_context = action_construction_context,
            cc_compilation_context = cc_compilation_context,
            cc_toolchain = cc_toolchain,
            configuration = configuration,
            feature_configuration = feature_configuration,
            compile_build_variables = _cc_internal.combine_cc_toolchain_variables(
                common_compile_build_variables,
                specific_compile_build_variables,
            ),
            source = source_dir,
            additional_compilation_inputs = additional_compilation_inputs,
            additional_include_scanning_roots = additional_include_scanning_roots,
            use_pic = use_pic,
            output_categories = output_categories,
            output_files = output_dir,
            dotd_tree_artifact = dotd_tree_artifact,
            diagnostics_tree_artifact = diagnostics_tree_artifact,
            lto_indexing_tree_artifact = lto_index_tree_artifact,
            needs_include_validation = cc_semantics.needs_include_validation(language),
            toolchain_type = cc_semantics.toolchain,
        )
    outputs[outputs_key].append(output_dir)

def _starlark_create_cc_compile_action_template(
        *,
        action_construction_context,
        cc_compilation_context,
        cc_toolchain,
        configuration,
        feature_configuration,
        compile_build_variables,
        source_dir,
        additional_compilation_inputs,
        additional_include_scanning_roots,
        use_pic,
        output_categories,
        output_dir,
        dotd_tree_artifact,
        diagnostics_tree_artifact,
        lto_indexing_tree_artifact,
        needs_include_validation,
        toolchain_type):
    # The setting of additional_inputs is important to prevent build failures stating that a file
    # "wasn't declared as input of map_directory()". This happens if an artifact's metadata is
    # pruned because no action declared to consume it - an "orphaned" file.
    # This is esp. true for cc_compilation_context.headers:
    # Even though cc_compilation_context is passed into map_directory() via additional_params,
    # the headers within it must also be added to additional_inputs so that map_directory() can
    # declare it is consuming these files, and thus their metadata is not pruned.
    # See b/527759856 for more details.
    additional_inputs = {
        "headers": (
            depset(additional_compilation_inputs, transitive = [cc_compilation_context.headers]) if additional_compilation_inputs else cc_compilation_context.headers
        ),
        "direct_module_maps": cc_compilation_context._direct_module_maps,
        "non_code_inputs": cc_compilation_context._non_code_inputs,
    }
    if cc_compilation_context._module_map and cc_compilation_context._module_map.file:
        additional_inputs["module_map"] = cc_compilation_context._module_map.file
    if feature_configuration.is_enabled(feature_names.USE_HEADER_MODULES):
        additional_inputs["transitive_modules"] = (
            cc_compilation_context._transitive_pic_modules if use_pic else cc_compilation_context._transitive_modules
        )
        separate_module = (
            cc_compilation_context._header_info.separate_pic_module if use_pic else cc_compilation_context._header_info.separate_module
        )
        if separate_module:
            additional_inputs["separate_module"] = separate_module

    tools = {
        "compiler_files": cc_toolchain._compiler_files,
        "compiler_files_without_includes": cc_toolchain._compiler_files_without_includes,
    }
    if cc_toolchain._grep_includes:
        tools["grep_includes"] = cc_toolchain._grep_includes

    additional_params = dict(
        cc_compilation_context = cc_compilation_context,  #  struct
        cc_toolchain = cc_toolchain,  # struct
        configuration = configuration,  # BuildConfigurationApi
        feature_configuration = feature_configuration,  # FeatureConfigurationApi
        compile_build_variables = compile_build_variables,  # CcToolchainVariablesApi
        additional_compilation_inputs = additional_compilation_inputs,  # list of File
        additional_include_scanning_roots = additional_include_scanning_roots,  # list of File
        use_pic = use_pic,  # boolean
        output_categories = output_categories,  # list of strings
        dotd_tree_artifact = dotd_tree_artifact,  # Artifact|NoneType
        diagnostics_tree_artifact = diagnostics_tree_artifact,  # Artifact|NoneType
        lto_indexing_tree_artifact = lto_indexing_tree_artifact,  # Artifact|NoneType
        needs_include_validation = needs_include_validation,  # boolean
        toolchain_type = toolchain_type,  # string
        should_compile_headers = feature_configuration.is_enabled("parse_headers"),  # boolean
    )

    output_directories = {"out_dir": output_dir}
    if dotd_tree_artifact:
        output_directories["dotd_out_dir"] = dotd_tree_artifact
    if diagnostics_tree_artifact:
        output_directories["diagnostics_out_dir"] = diagnostics_tree_artifact
    if lto_indexing_tree_artifact:
        output_directories["lto_indexing_out_dir"] = lto_indexing_tree_artifact

    action_construction_context.actions.map_directory(
        implementation = _template_impl,
        input_directories = {"in_dir": source_dir},
        output_directories = output_directories,
        additional_inputs = additional_inputs,
        additional_params = additional_params,
        mnemonic = "CcCompileActionTemplate",
        tools = tools,
        toolchain = cc_semantics.toolchain,
    )

def _template_impl(
        template_ctx,
        input_directories,
        output_directories,
        additional_inputs,  # @unused
        tools,  # @unused
        additional_params):
    # additional_inputs isn't used inside _template_impl() because the contained files are covered
    # by input discovery via include scanning.
    # But additional_inputs must be passed into map_directory() so the inputs are know to bazel and
    # their metadata isn't pruned as orphaned input files.
    in_dir = input_directories["in_dir"]
    out_dir = output_directories["out_dir"]

    source_files = []
    private_headers = []

    for input_file in in_dir.children:
        extension_with_dot = "." + input_file.extension
        is_header = extension_with_dot in extensions.CC_HEADER
        is_textual_include = extension_with_dot in extensions.CC_TEXTUAL_INCLUDE
        is_source = extension_with_dot in extensions.CC_AND_OBJC_SOURCE

        if is_header:
            private_headers.append(input_file)
        if is_source or (is_header and additional_params["should_compile_headers"] and not is_textual_include):
            source_files.append(input_file)
        elif not is_header:
            fail(("Artifact '%s' expanded from the directory artifact '%s' is neither header nor source file." +
                  " input_file.extension = %s") % (input_file.path, in_dir.directory.path, input_file.extension))

    private_headers_depset = depset(direct = private_headers)

    for source_file in source_files:
        output_file_name = _compute_output_file_name(
            source_file,
            additional_params["output_categories"],
            additional_params["cc_toolchain"],
        )
        output_file = template_ctx.declare_file(output_file_name, directory = out_dir)
        dotd_file = None
        if (
            additional_params["dotd_tree_artifact"] and
            use_dotd_file(additional_params["feature_configuration"], source_file)
        ):
            dotd_file = template_ctx.declare_file(
                output_file_name + ".d",
                directory = additional_params["dotd_tree_artifact"],
            )
        diagnostics_file = None
        if additional_params["diagnostics_tree_artifact"]:
            diagnostics_file = template_ctx.declare_file(
                output_file_name + ".dia",
                directory = additional_params["diagnostics_tree_artifact"],
            )
        lto_indexing_file = None
        if additional_params["lto_indexing_tree_artifact"]:
            lto_index_file_name = paths.replace_extension(output_file_name, ".indexing.o")
            lto_indexing_file = template_ctx.declare_file(
                lto_index_file_name,
                directory = additional_params["lto_indexing_tree_artifact"],
            )

        added_build_variables = get_template_added_build_variables(
            source_file = source_file,
            output_file = output_file,
            dotd_file = dotd_file,
            diagnostics_file = diagnostics_file,
            lto_indexing_file = lto_indexing_file,
        )

        compile_build_variables = _cc_internal.combine_cc_toolchain_variables(
            additional_params["compile_build_variables"],
            added_build_variables,
        )

        _cc_internal.create_cc_compile_action(
            action_construction_context = template_ctx,
            cc_compilation_context = additional_params["cc_compilation_context"],
            cc_toolchain = additional_params["cc_toolchain"],
            configuration = additional_params["configuration"],
            feature_configuration = additional_params["feature_configuration"],
            additional_compilation_inputs = additional_params["additional_compilation_inputs"],
            additional_include_scanning_roots = additional_params["additional_include_scanning_roots"],
            source = source_file,
            output_file = output_file,
            diagnostics_file = diagnostics_file,
            dotd_file = dotd_file,
            use_pic = additional_params["use_pic"],
            lto_indexing_file = lto_indexing_file,
            compile_build_variables = compile_build_variables,
            needs_include_validation = additional_params["needs_include_validation"],
            toolchain_type = additional_params["toolchain_type"],
            additional_prunable_headers = private_headers_depset,
        )

def _compute_output_file_name(input_file, output_categories, cc_toolchain):
    output_file_name = paths.split_extension(input_file.tree_relative_path)[0]
    for category in output_categories:
        output_file_name = _cc_internal.get_artifact_name_for_category(
            cc_toolchain = cc_toolchain,
            category = category,
            output_name = output_file_name,
        )
    return output_file_name

def _declare_compile_output_tree_artifact(
        ctx,
        label,
        output_name,
        use_pic):
    return ctx.actions.declare_directory(paths.join(
        "_pic_objs" if use_pic else "_objs",
        label.name,
        output_name,
    ))

def _maybe_declare_dotd_tree_artifact(
        ctx,
        feature_configuration,
        language,
        label,
        output_name,
        use_pic):
    if not dotd_files_enabled(language, ctx.fragments.cpp, feature_configuration):
        return None
    return ctx.actions.declare_directory(paths.join(
        "_pic_dotd" if use_pic else "_dotd",
        label.name,
        output_name,
    ))

def _maybe_declare_diagnostics_tree_artifact(
        ctx,
        feature_configuration,
        label,
        output_name,
        use_pic):
    if not serialized_diagnostics_file_enabled(feature_configuration):
        return None
    return ctx.actions.declare_directory(paths.join(
        "_pic_dia" if use_pic else "_dia",
        label.name,
        output_name,
    ))
