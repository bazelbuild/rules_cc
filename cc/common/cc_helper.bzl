# Copyright 2020 The Bazel Authors. All rights reserved.
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
"""Utility functions for C++ rules."""

load("//cc:find_cc_toolchain.bzl", "CC_TOOLCHAIN_TYPE")
load(":cc_common.bzl", "cc_common")
load(
    ":cc_helper_internal.bzl",
    "get_relative_path",
    "is_versioned_shared_library_extension_valid",
    "path_contains_up_level_references",
    _artifact_category = "artifact_category",
    _package_source_root = "package_source_root",
    _repository_exec_path = "repository_exec_path",
)
load(":cc_info.bzl", "CcInfo")
load(":visibility.bzl", "INTERNAL_VISIBILITY")

visibility(INTERNAL_VISIBILITY)

# LINT.IfChange(linker_mode)
linker_mode = struct(
    LINKING_DYNAMIC = "dynamic_linking_mode",
    LINKING_STATIC = "static_linking_mode",
)
# LINT.ThenChange(https://github.com/bazelbuild/bazel/blob/master/src/main/starlark/builtins_bzl/common/cc/cc_helper.bzl:linker_mode)

# LINT.IfChange(forked_exports)

artifact_category = _artifact_category

def _is_non_empty_list_or_select(value, attr):
    if type(value) == "list":
        return len(value) > 0
    elif type(value) == "select":
        return True
    else:
        fail("Only select or list is valid for {} attr".format(attr))

def _gen_empty_def_file(ctx):
    trivial_def_file = ctx.actions.declare_file(ctx.label.name + ".gen.empty.def")
    ctx.actions.write(trivial_def_file, "", False)
    return trivial_def_file

def _get_windows_def_file_for_linking(ctx, custom_def_file, generated_def_file, feature_configuration):
    # 1. If a custom DEF file is specified in win_def_file attribute, use it.
    # 2. If a generated DEF file is available and should be used, use it.
    # 3. Otherwise, we use an empty DEF file to ensure the import library will be generated.
    if custom_def_file != None:
        return custom_def_file
    elif generated_def_file != None and _should_generate_def_file(ctx, feature_configuration) == True:
        return generated_def_file
    else:
        return _gen_empty_def_file(ctx)

def _should_generate_def_file(ctx, feature_configuration):
    windows_export_all_symbols_enabled = cc_common.is_enabled(feature_configuration = feature_configuration, feature_name = "windows_export_all_symbols")
    no_windows_export_all_symbols_enabled = cc_common.is_enabled(feature_configuration = feature_configuration, feature_name = "no_windows_export_all_symbols")
    return windows_export_all_symbols_enabled and (not no_windows_export_all_symbols_enabled) and (ctx.attr.win_def_file == None)

def _generate_def_file(ctx, def_parser, object_files, dll_name):
    def_file = ctx.actions.declare_file(ctx.label.name + ".gen.def")
    args = ctx.actions.args()
    args.add(def_file)
    args.add(dll_name)
    argv = ctx.actions.args()
    argv.use_param_file("@%s", use_always = True)
    argv.set_param_file_format("shell")
    for object_file in object_files:
        argv.add(object_file.path)

    ctx.actions.run(
        mnemonic = "DefParser",
        executable = def_parser,
        toolchain = None,
        arguments = [args, argv],
        inputs = object_files,
        outputs = [def_file],
        use_default_shell_env = True,
    )
    return def_file

def _stringify_linker_input(linker_input):
    parts = []
    parts.append(str(linker_input.owner))
    for library in linker_input.libraries:
        if library.static_library != None:
            parts.append(library.static_library.path)
        if library.pic_static_library != None:
            parts.append(library.pic_static_library.path)
        if library.dynamic_library != None:
            parts.append(library.dynamic_library.path)
        if library.interface_library != None:
            parts.append(library.interface_library.path)

    for additional_input in linker_input.additional_inputs:
        parts.append(additional_input.path)

    for linkstamp in linker_input.linkstamps:
        parts.append(linkstamp.file().path)

    return "".join(parts)

def _get_compilation_contexts_from_deps(deps):
    compilation_contexts = []
    for dep in deps:
        if CcInfo in dep:
            compilation_contexts.append(dep[CcInfo].compilation_context)
    return compilation_contexts

def _tool_path(cc_toolchain, tool):
    return cc_toolchain._tool_paths.get(tool, None)

def _get_toolchain_global_make_variables(cc_toolchain):
    result = {
        "CC": _tool_path(cc_toolchain, "gcc"),
        "AR": _tool_path(cc_toolchain, "ar"),
        "NM": _tool_path(cc_toolchain, "nm"),
        "LD": _tool_path(cc_toolchain, "ld"),
        "STRIP": _tool_path(cc_toolchain, "strip"),
        "C_COMPILER": cc_toolchain.compiler,
    }  # buildifier: disable=unsorted-dict-items

    obj_copy_tool = _tool_path(cc_toolchain, "objcopy")
    if obj_copy_tool != None:
        # objcopy is optional in Crostool.
        result["OBJCOPY"] = obj_copy_tool
    gcov_tool = _tool_path(cc_toolchain, "gcov-tool")
    if gcov_tool != None:
        # gcovtool is optional in Crostool.
        result["GCOVTOOL"] = gcov_tool

    libc = cc_toolchain.libc
    if libc.startswith("glibc-"):
        # Strip "glibc-" prefix.
        result["GLIBC_VERSION"] = libc[6:]
    else:
        result["GLIBC_VERSION"] = libc

    abi_glibc_version = cc_toolchain._abi_glibc_version
    if abi_glibc_version != None:
        result["ABI_GLIBC_VERSION"] = abi_glibc_version

    abi = cc_toolchain._abi
    if abi != None:
        result["ABI"] = abi

    result["CROSSTOOLTOP"] = cc_toolchain._crosstool_top_path
    return result

_SHARED_LIBRARY_EXTENSIONS = ["so", "dll", "dylib", "wasm"]

def _is_valid_shared_library_artifact(shared_library):
    if (shared_library.extension in _SHARED_LIBRARY_EXTENSIONS):
        return True

    return is_versioned_shared_library_extension_valid(shared_library.basename)

def _get_static_mode_params_for_dynamic_library_libraries(libs):
    linker_inputs = []
    for lib in libs.to_list():
        if lib.pic_static_library:
            linker_inputs.append(lib.pic_static_library)
        elif lib.static_library:
            linker_inputs.append(lib.static_library)
        elif lib.interface_library:
            linker_inputs.append(lib.interface_library)
        else:
            linker_inputs.append(lib.dynamic_library)
    return linker_inputs

def _create_strip_action(ctx, cc_toolchain, cpp_config, input, output, feature_configuration):
    if cc_common.is_enabled(feature_configuration = feature_configuration, feature_name = "no_stripping"):
        ctx.actions.symlink(
            output = output,
            target_file = input,
            progress_message = "Symlinking original binary as stripped binary",
        )
        return

    if not cc_common.action_is_enabled(feature_configuration = feature_configuration, action_name = "strip"):
        fail("Expected action_config for 'strip' to be configured.")

    variables = cc_common.create_compile_variables(
        cc_toolchain = cc_toolchain,
        feature_configuration = feature_configuration,
        output_file = output.path,
        input_file = input.path,
        strip_opts = cpp_config.strip_opts(),
    )
    command_line = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = "strip",
        variables = variables,
    )
    env = cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = "strip",
        variables = variables,
    )
    execution_info = {}
    for execution_requirement in cc_common.get_tool_requirement_for_action(feature_configuration = feature_configuration, action_name = "strip"):
        execution_info[execution_requirement] = ""
    ctx.actions.run(
        inputs = depset(
            direct = [input],
            transitive = [cc_toolchain._strip_files],
        ),
        outputs = [output],
        use_default_shell_env = True,
        env = env,
        executable = cc_common.get_tool_for_action(feature_configuration = feature_configuration, action_name = "strip"),
        toolchain = CC_TOOLCHAIN_TYPE,
        execution_requirements = execution_info,
        progress_message = "Stripping {} for {}".format(output.short_path, ctx.label),
        mnemonic = "CcStrip",
        arguments = command_line,
    )

def _lookup_var(ctx, additional_vars, var):
    expanded_make_var_ctx = ctx.var.get(var)
    expanded_make_var_additional = additional_vars.get(var)
    if expanded_make_var_additional != None:
        return expanded_make_var_additional
    if expanded_make_var_ctx != None:
        return expanded_make_var_ctx
    fail("{}: {} not defined".format(ctx.label, "$(" + var + ")"))

def _expand_nested_variable(ctx, additional_vars, exp, execpath = True, targets = []):
    # If make variable is predefined path variable(like $(location ...))
    # we will expand it first.
    if exp.find(" ") != -1:
        if not execpath:
            if exp.startswith("location"):
                exp = exp.replace("location", "rootpath", 1)
        data_targets = []
        if ctx.attr.data != None:
            data_targets = ctx.attr.data

        # Make sure we do not duplicate targets.
        unified_targets_set = {}
        for data_target in data_targets:
            unified_targets_set[data_target] = True
        for target in targets:
            unified_targets_set[target] = True
        return ctx.expand_location("$({})".format(exp), targets = unified_targets_set.keys())

    # Recursively expand nested make variables, but since there is no recursion
    # in Starlark we will do it via for loop.
    unbounded_recursion = True

    # The only way to check if the unbounded recursion is happening or not
    # is to have a look at the depth of the recursion.
    # 10 seems to be a reasonable number, since it is highly unexpected
    # to have nested make variables which are expanding more than 10 times.
    for _ in range(10):
        exp = _lookup_var(ctx, additional_vars, exp)
        if len(exp) >= 3 and exp[0] == "$" and exp[1] == "(" and exp[len(exp) - 1] == ")":
            # Try to expand once more.
            exp = exp[2:len(exp) - 1]
            continue
        unbounded_recursion = False
        break

    if unbounded_recursion:
        fail("potentially unbounded recursion during expansion of {}".format(exp))
    return exp

def _expand(ctx, expression, additional_make_variable_substitutions, execpath = True, targets = []):
    idx = 0
    last_make_var_end = 0
    result = []
    n = len(expression)
    for _ in range(n):
        if idx >= n:
            break
        if expression[idx] != "$":
            idx += 1
            continue

        idx += 1

        # We've met $$ pattern, so $ is escaped.
        if idx < n and expression[idx] == "$":
            idx += 1
            result.append(expression[last_make_var_end:idx - 1])
            last_make_var_end = idx
            # We might have found a potential start for Make Variable.

        elif idx < n and expression[idx] == "(":
            # Try to find the closing parentheses.
            make_var_start = idx
            make_var_end = make_var_start
            for j in range(idx + 1, n):
                if expression[j] == ")":
                    make_var_end = j
                    break

            # Note we cannot go out of string's bounds here,
            # because of this check.
            # If start of the variable is different from the end,
            # we found a make variable.
            if make_var_start != make_var_end:
                # Some clarifications:
                # *****$(MAKE_VAR_1)*******$(MAKE_VAR_2)*****
                #                   ^       ^          ^
                #                   |       |          |
                #   last_make_var_end  make_var_start make_var_end
                result.append(expression[last_make_var_end:make_var_start - 1])
                make_var = expression[make_var_start + 1:make_var_end]
                exp = _expand_nested_variable(ctx, additional_make_variable_substitutions, make_var, execpath, targets)
                result.append(exp)

                # Update indexes.
                idx = make_var_end + 1
                last_make_var_end = idx

    # Add the last substring which would be skipped by for loop.
    if last_make_var_end < n:
        result.append(expression[last_make_var_end:n])

    return "".join(result)

def _get_expanded_env(ctx, additional_make_variable_substitutions):
    if not hasattr(ctx.attr, "env"):
        fail("could not find rule attribute named: 'env'")
    expanded_env = {}
    for k in ctx.attr.env:
        expanded_env[k] = _expand(
            ctx,
            ctx.attr.env[k],
            additional_make_variable_substitutions,
            # By default, Starlark `ctx.expand_location` has `execpath` semantics.
            # For legacy attributes, e.g. `env`, we want `rootpath` semantics instead.
            execpath = False,
        )
    return expanded_env

# Implementation of Bourne shell tokenization.
# Tokenizes str and appends result to the options list.
def _tokenize(options, options_string):
    token = []
    force_token = False
    quotation = "\0"
    length = len(options_string)

    # Since it is impossible to modify loop variable inside loop
    # in Starlark, and also there is no while loop, I have to
    # use this ugly hack.
    i = -1
    for _ in range(length):
        i += 1
        if i >= length:
            break
        c = options_string[i]
        if quotation != "\0":
            # In quotation.
            if c == quotation:
                # End quotation.
                quotation = "\0"
            elif c == "\\" and quotation == "\"":
                i += 1
                if i == length:
                    fail("backslash at the end of the string: {}".format(options_string))
                c = options_string[i]
                if c != "\\" and c != "\"":
                    token.append("\\")
                token.append(c)
            else:
                # Regular char, in quotation.
                token.append(c)
        else:
            # Not in quotation.
            if c == "'" or c == "\"":
                # Begin single double quotation.
                quotation = c
                force_token = True
            elif c == " " or c == "\t":
                # Space not quoted.
                if force_token or len(token) > 0:
                    options.append("".join(token))
                    token = []
                    force_token = False
            elif c == "\\":
                # Backslash not quoted.
                i += 1
                if i == length:
                    fail("backslash at the end of the string: {}".format(options_string))
                token.append(options_string[i])
            else:
                # Regular char, not quoted.
                token.append(c)
    if quotation != "\0":
        fail("unterminated quotation at the end of the string: {}".format(options_string))

    if force_token or len(token) > 0:
        options.append("".join(token))

def _should_use_pic(ctx, cc_toolchain, feature_configuration):
    """Whether to use pic files

    Args:
        ctx: (RuleContext)
        cc_toolchain: (CcToolchainInfo)
        feature_configuration: (FeatureConfiguration)

    Returns:
        (bool)
    """
    return ctx.fragments.cpp.force_pic() or (
        cc_toolchain.needs_pic_for_dynamic_libraries(feature_configuration = feature_configuration) and (
            ctx.var["COMPILATION_MODE"] != "opt" or
            cc_common.is_enabled(feature_configuration = feature_configuration, feature_name = "prefer_pic_for_opt_binaries")
        )
    )

SYSROOT_FLAG = "--sysroot="

def _contains_sysroot(original_cc_flags, feature_config_cc_flags):
    if SYSROOT_FLAG in original_cc_flags:
        return True
    for flag in feature_config_cc_flags:
        if SYSROOT_FLAG in flag:
            return True

    return False

def _get_cc_flags_make_variable(_ctx, feature_configuration, cc_toolchain):
    original_cc_flags = cc_toolchain._legacy_cc_flags_make_variable
    sysroot_cc_flag = ""
    if cc_toolchain.sysroot != None:
        sysroot_cc_flag = SYSROOT_FLAG + cc_toolchain.sysroot

    build_vars = cc_toolchain._build_variables
    feature_config_cc_flags = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = "cc-flags-make-variable",
        variables = build_vars,
    )
    cc_flags = [original_cc_flags]

    # Only add sysroots flag if nothing else adds sysroot, BUT it must appear
    # before the feature config flags.
    if not _contains_sysroot(original_cc_flags, feature_config_cc_flags):
        cc_flags.append(sysroot_cc_flag)
    cc_flags.extend(feature_config_cc_flags)
    return {"CC_FLAGS": " ".join(cc_flags)}

def _package_exec_path(ctx, package, sibling_repository_layout):
    return get_relative_path(_repository_exec_path(ctx.label.workspace_name, sibling_repository_layout), package)

def _system_include_dirs(ctx, additional_make_variable_substitutions):
    result = []
    sibling_repository_layout = ctx.configuration.is_sibling_repository_layout()
    package = ctx.label.package
    package_exec_path = _package_exec_path(ctx, package, sibling_repository_layout)
    package_source_root = _package_source_root(ctx.label.workspace_name, package, sibling_repository_layout)
    for include in ctx.attr.includes:
        includes_attr = _expand(ctx, include, additional_make_variable_substitutions)
        if includes_attr.startswith("/"):
            continue
        includes_path = get_relative_path(package_exec_path, includes_attr)
        if not sibling_repository_layout and path_contains_up_level_references(includes_path):
            fail("Path references a path above the execution root.", attr = "includes")

        if includes_path == ".":
            fail("'" + includes_attr + "' resolves to the workspace root, which would allow this rule and all of its " +
                 "transitive dependents to include any file in your workspace. Please include only" +
                 " what you need", attr = "includes")
        result.append(includes_path)

        # We don't need to perform the above checks against out_includes_path again since any errors
        # must have manifested in includesPath already.
        out_includes_path = get_relative_path(package_source_root, includes_attr)
        if (ctx.configuration.has_separate_genfiles_directory()):
            result.append(get_relative_path(ctx.genfiles_dir.path, out_includes_path))
        result.append(get_relative_path(ctx.bin_dir.path, out_includes_path))
    return result

cc_helper = struct(
    create_strip_action = _create_strip_action,
    get_expanded_env = _get_expanded_env,
    get_static_mode_params_for_dynamic_library_libraries = _get_static_mode_params_for_dynamic_library_libraries,
    should_use_pic = _should_use_pic,
    tokenize = _tokenize,
    is_valid_shared_library_artifact = _is_valid_shared_library_artifact,
    get_toolchain_global_make_variables = _get_toolchain_global_make_variables,
    get_cc_flags_make_variable = _get_cc_flags_make_variable,
    get_compilation_contexts_from_deps = _get_compilation_contexts_from_deps,
    system_include_dirs = _system_include_dirs,
    stringify_linker_input = _stringify_linker_input,
    generate_def_file = _generate_def_file,
    get_windows_def_file_for_linking = _get_windows_def_file_for_linking,
    is_non_empty_list_or_select = _is_non_empty_list_or_select,
)
# LINT.ThenChange(https://github.com/bazelbuild/bazel/blob/master/src/main/starlark/builtins_bzl/common/cc/cc_helper.bzl:forked_exports)
