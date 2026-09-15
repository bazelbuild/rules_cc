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
load("//cc/common:visibility.bzl", "PRIVATE_RULES_ALLOWLIST")
load("//cc/private:cc_internal.bzl", _cc_internal = "cc_internal")
load("//cc/private:paths.bzl", "is_path_absolute")

def check_private_api():
    _cc_internal.check_private_api(allowlist = PRIVATE_STARLARKIFICATION_ALLOWLIST, depth = 2)

def wrap_with_check_private_api(symbol):
    """
    Protects the symbol so it can only be used internally.

    Returns:
      A function. When the function is invoked (without any params), the check
      is done and if it passes the symbol is returned.
    """

    def callback():
        _cc_internal.check_private_api(allowlist = PRIVATE_STARLARKIFICATION_ALLOWLIST)
        return symbol

    return callback

def _lookup_var(ctx, additional_vars, var):
    expanded_make_var_ctx = ctx.var.get(var)
    expanded_make_var_additional = additional_vars.get(var)
    if expanded_make_var_additional != None:
        return expanded_make_var_additional
    if expanded_make_var_ctx != None:
        return expanded_make_var_ctx
    fail("{}: {} not defined".format(ctx.label, "$(" + var + ")"))

def expand_nested_variable(ctx, additional_vars, exp, execpath = True, targets = []):
    """Expands one Make variable or location expression.

    Args:
      ctx: The rule context containing Make variables and prerequisites.
      additional_vars: Additional Make-variable substitutions.
      exp: The Make-variable name or location expression without surrounding "$()".
      execpath: Whether location expressions use execution paths.
      targets: Additional targets available to location expressions.

    Returns:
      The expanded Make-variable value or location path.
    """

    # If make variable is predefined path variable(like $(location ...))
    # we will expand it first.
    if exp.find(" ") != -1:
        if not execpath:
            if exp.startswith("location"):
                exp = exp.replace("location", "rootpath", 1)
        data_targets = getattr(ctx.attr, "data", []) or []

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

def expand(ctx, expression, additional_make_variable_substitutions, execpath = True, targets = []):
    """Expands Make variables and prerequisite locations in an expression.

    Args:
      ctx: The rule context containing Make variables and prerequisites.
      expression: The expression containing Make variables or location expressions.
      additional_make_variable_substitutions: Additional Make-variable substitutions.
      execpath: Whether location expressions use execution paths.
      targets: Additional targets available to location expressions.

    Returns:
      The expression with Make variables and location expressions expanded.
    """
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
                exp = expand_nested_variable(ctx, additional_make_variable_substitutions, make_var, execpath, targets)
                result.append(exp)

                # Update indexes.
                idx = make_var_end + 1
                last_make_var_end = idx

    # Add the last substring which would be skipped by for loop.
    if last_make_var_end < n:
        result.append(expression[last_make_var_end:n])

    return "".join(result)

def tokenize(options, options_string):
    """Appends Bourne-shell tokens from options_string to options.

    Args:
      options: The list receiving the parsed shell tokens.
      options_string: The shell-tokenized string.
    """
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

CPP_SOURCE_TYPE_HEADER = "HEADER"
CPP_SOURCE_TYPE_SOURCE = "SOURCE"
CPP_SOURCE_TYPE_CLIF_INPUT_PROTO = "CLIF_INPUT_PROTO"
CC_RUNTIMES_TOOLCHAIN_TYPE = Label("@bazel_tools//tools/cpp:cc_runtimes_toolchain_type")

def get_cc_runtimes(ctx, is_library):
    """Returns the list of C++ runtime dependency targets for the rule.

    Args:
      ctx: The rule context.
      is_library: True if the target being evaluated is a library rule (which
        excludes malloc and link_extra_lib), False otherwise.

    Returns:
      A list of Target objects representing the required runtime libraries.
    """
    runtimes = []

    # Executable builds also include the "malloc" and "link_extra_lib" libraries.
    if not is_library:
        runtimes.append(ctx.attr.link_extra_lib)

        if ctx.fragments.cpp.custom_malloc != None:
            # ctx.attr._default_malloc is set via ctx.fragments.cpp.custom_malloc.
            runtimes.append(ctx.attr._default_malloc)
        else:
            runtimes.append(ctx.attr.malloc)

    cc_runtimes_toolchain = ctx.toolchains[CC_RUNTIMES_TOOLCHAIN_TYPE]

    # All builds include the runtimes from the cc_runtimes_toolchain.
    if cc_runtimes_toolchain:
        runtimes += cc_runtimes_toolchain.cc_runtimes_info.runtimes
    elif hasattr(ctx.attr, "tags") and "__CC_STL__" in ctx.attr.tags:
        # TODO(b/141613846): Remove this workaround.
        pass
    elif getattr(ctx.attr, "_stl", None) != None:
        runtimes.append(ctx.attr._stl)

    return runtimes

def get_cc_runtimes_copts(ctx):
    """Returns the C++ compiler flags required by the C++ runtimes toolchain.

    Args:
      ctx: The rule context.

    Returns:
      A list of command-line compiler option strings from the runtimes toolchain.
    """
    cc_runtimes_toolchain = ctx.toolchains[CC_RUNTIMES_TOOLCHAIN_TYPE]
    return cc_runtimes_toolchain.cc_runtimes_info.copts if cc_runtimes_toolchain else []

def get_fdo_build_stamp(cpp_configuration, fdo_context, feature_configuration):
    """Returns the FDO build stamp.

    Args:
      cpp_configuration: The C++ configuration.
      fdo_context: The FDO context.
      feature_configuration: The feature configuration.

    Returns:
      The FDO build stamp string, or None if FDO is not enabled.
    """
    branch_fdo_profile = getattr(fdo_context, "branch_fdo_profile", None)
    if branch_fdo_profile:
        branch_fdo_mode = branch_fdo_profile.branch_fdo_mode
        if branch_fdo_mode == "auto_fdo":
            return "AFDO" if feature_configuration.is_enabled("autofdo") else None
        if branch_fdo_mode == "xbinary_fdo":
            return "XFDO" if feature_configuration.is_enabled("xbinaryfdo") else None
        if branch_fdo_mode == "llvm_cs_fdo" or cpp_configuration.cs_fdo_instrument():
            return "CSFDO"
    if branch_fdo_profile or cpp_configuration.fdo_instrument():
        return "FDO"
    return None

def get_linkstamp_stamps(
        cc_toolchain,
        feature_configuration,
        target_name,
        build_target,
        additional_linkstamp_defines):
    """Returns a dict of stamps for linkstamp compilation/PostMark.

    Args:
      cc_toolchain: The C++ toolchain provider.
      feature_configuration: The feature configuration.
      target_name: Value for the G3_TARGET_NAME linkstamp define.
      build_target: Value for the G3_BUILD_TARGET linkstamp define.
      additional_linkstamp_defines: A list of additional defines for linkstamp compilation.

    Returns:
      A dictionary of linkstamp defines.
    """
    fdo_build_stamp = get_fdo_build_stamp(
        cc_toolchain._cpp_configuration,
        cc_toolchain._fdo_context,
        feature_configuration,
    )
    stamps = {
        "GPLATFORM": cc_toolchain.toolchain_id,
        "BUILD_COVERAGE_ENABLED": "1" if feature_configuration.is_enabled("coverage") else "0",
        # G3_TARGET_NAME is a C string literal that normally contain the label of the target
        # being linked.  However, they are set differently when using shared native deps. In
        # that case, a single .so file is shared by multiple targets, and its contents cannot
        # depend on which target(s) were specified on the command line.  So in that case we
        # have to use the (obscure) name of the .so file instead, or more precisely the path of
        # the .so file relative to the workspace root.
        "G3_TARGET_NAME": target_name,
        # G3_BUILD_TARGET is a C string literal containing the output of this
        # link.  (An undocumented and untested invariant is that G3_BUILD_TARGET is the
        # location of the executable, either absolutely, or relative to the directory part of
        # BUILD_INFO.)
        "G3_BUILD_TARGET": build_target,
    }
    if fdo_build_stamp:
        stamps["BUILD_FDO_TYPE"] = fdo_build_stamp

    fdo_context = getattr(cc_toolchain, "_fdo_context", None)
    if fdo_context:
        fdo_profile_changelist = getattr(fdo_context, "fdo_profile_changelist", None)
        if fdo_profile_changelist:
            stamps["BUILD_FDO_PROFILE_CHANGELIST"] = fdo_profile_changelist
        memprof_profile_changelist = getattr(fdo_context, "memprof_profile_changelist", None)
        if memprof_profile_changelist:
            stamps["BUILD_MEMPROF_PROFILE_CHANGELIST"] = memprof_profile_changelist

    if feature_configuration.is_enabled("thin_lto"):
        stamps["BUILD_LTO_TYPE"] = "thin"

    if additional_linkstamp_defines:
        for d in additional_linkstamp_defines:
            if "=" in d:
                k, v = d.split("=", 1)
                stamps[k] = v
            else:
                stamps[d] = "1"

    return stamps

# LINT.IfChange(forked_exports)

CREATE_COMPILE_ACTION_API_ALLOWLISTED_PACKAGES = [("", "devtools/rust/cc_interop"), ("", "third_party/crubit"), ("", "tools/build_defs/clif")]

PRIVATE_STARLARKIFICATION_ALLOWLIST = [
    ("_builtins", ""),
    # Android rules
    ("", "tools/build_defs/android"),
    ("", "third_party/bazel_rules/rules_android"),
    ("build_bazel_rules_android", ""),
    ("rules_android", ""),
    # Apple rules
    ("", "third_party/bazel_rules/rules_apple"),
    ("apple_support", ""),
    ("build_bazel_apple_support", ""),
    ("rules_apple", ""),
    ("build_bazel_rules_apple", ""),
    # C++ rules
    ("", "bazel_internal/test_rules/cc"),
    ("", "third_party/bazel_rules/rules_cc"),
    ("", "tools/build_defs/cc"),
    ("rules_cc", ""),
    # CUDA rules
    ("", "third_party/gpus/cuda"),
    # Go rules
    ("", "tools/build_defs/go"),
    # Java rules
    ("", "third_party/bazel_rules/rules_java"),
    ("rules_java", ""),
    # Objc rules
    ("", "tools/build_defs/objc"),
    # Protobuf rules
    ("", "third_party/protobuf"),
    ("protobuf", ""),
    ("com_google_protobuf", ""),
    ("", "third_party/upb"),
    # Rust rules
    ("", "third_party/bazel_rules/rules_rust/rust/private"),
    ("rules_rust", "rust/private"),
    ("rules_rs", "rust/private"),
    # Python rules
    ("", "third_party/bazel_rules/rules_python"),
    # Various
    ("", "research/colab"),
    ("", "javatests/com/google/devtools/grok/kythe"),
] + CREATE_COMPILE_ACTION_API_ALLOWLISTED_PACKAGES + PRIVATE_RULES_ALLOWLIST

# LINT.ThenChange(https://github.com/bazelbuild/bazel/blob/master/src/main/starlark/builtins_bzl/common/cc/cc_helper_internal.bzl:forked_exports)

_CC_SOURCE = [".cc", ".cpp", ".cxx", ".c++", ".C", ".cu", ".cl"]
_C_SOURCE = [".c"]
_OBJC_SOURCE = [".m"]
_OBJCPP_SOURCE = [".mm"]
_CLIF_INPUT_PROTO = [".ipb"]
_CLIF_OUTPUT_PROTO = [".opb"]
_CC_HEADER = [".h", ".hh", ".hpp", ".ipp", ".hxx", ".h++", ".inc", ".inl", ".tlh", ".tli", ".H", ".tcc"]
_CC_TEXTUAL_INCLUDE = [".inc"]
_ASSEMBLER_WITH_C_PREPROCESSOR = [".S"]
_ASSEMBLER = [".s", ".asm"]
_ARCHIVE = [".a", ".lib"]
_PIC_ARCHIVE = [".pic.a"]
_ALWAYSLINK_LIBRARY = [".lo"]
_ALWAYSLINK_PIC_LIBRARY = [".pic.lo"]
_SHARED_LIBRARY = [".so", ".dylib", ".dll", ".pyd", ".wasm", ".xll"]
_INTERFACE_SHARED_LIBRARY = [".ifso", ".tbd", ".lib", ".dll.a"]
_OBJECT_FILE = [".o", ".obj"]
_PIC_OBJECT_FILE = [".pic.o"]
_CPP_MODULE = [".pcm", ".gcm", ".ifc"]
_CPP_MODULE_MAP = [".cppmap"]
_LTO_INDEXING_OBJECT_FILE = [".indexing.o"]

_CC_AND_OBJC = []
_CC_AND_OBJC.extend(_CC_SOURCE)
_CC_AND_OBJC.extend(_C_SOURCE)
_CC_AND_OBJC.extend(_OBJC_SOURCE)
_CC_AND_OBJC.extend(_OBJCPP_SOURCE)
_CC_AND_OBJC.extend(_CC_HEADER)
_CC_AND_OBJC.extend(_ASSEMBLER)
_CC_AND_OBJC.extend(_ASSEMBLER_WITH_C_PREPROCESSOR)

_DISALLOWED_HDRS_FILES = []
_DISALLOWED_HDRS_FILES.extend(_ARCHIVE)
_DISALLOWED_HDRS_FILES.extend(_PIC_ARCHIVE)
_DISALLOWED_HDRS_FILES.extend(_ALWAYSLINK_LIBRARY)
_DISALLOWED_HDRS_FILES.extend(_ALWAYSLINK_PIC_LIBRARY)
_DISALLOWED_HDRS_FILES.extend(_SHARED_LIBRARY)
_DISALLOWED_HDRS_FILES.extend(_INTERFACE_SHARED_LIBRARY)
_DISALLOWED_HDRS_FILES.extend(_OBJECT_FILE)
_DISALLOWED_HDRS_FILES.extend(_PIC_OBJECT_FILE)

extensions = struct(
    CC_SOURCE = _CC_SOURCE,
    C_SOURCE = _C_SOURCE,
    OBJC_SOURCE = _OBJC_SOURCE,
    OBJCPP_SOURCE = _OBJCPP_SOURCE,
    CC_HEADER = _CC_HEADER,
    CC_TEXTUAL_INCLUDE = _CC_TEXTUAL_INCLUDE,
    ASSEMBLER_WITH_C_PREPROCESSOR = _ASSEMBLER_WITH_C_PREPROCESSOR,
    ASSEMBLER = _ASSEMBLER,
    CLIF_INPUT_PROTO = _CLIF_INPUT_PROTO,
    CLIF_OUTPUT_PROTO = _CLIF_OUTPUT_PROTO,
    ARCHIVE = _ARCHIVE,
    PIC_ARCHIVE = _PIC_ARCHIVE,
    ALWAYSLINK_LIBRARY = _ALWAYSLINK_LIBRARY,
    ALWAYSLINK_PIC_LIBRARY = _ALWAYSLINK_PIC_LIBRARY,
    SHARED_LIBRARY = _SHARED_LIBRARY,
    INTERFACE_SHARED_LIBRARY = _INTERFACE_SHARED_LIBRARY,
    OBJECT_FILE = _OBJECT_FILE,
    PIC_OBJECT_FILE = _PIC_OBJECT_FILE,
    CC_AND_OBJC = _CC_AND_OBJC,
    DISALLOWED_HDRS_FILES = _DISALLOWED_HDRS_FILES,  # Also includes VERSIONED_SHARED_LIBRARY files.
    CPP_MODULE = _CPP_MODULE,
    CPP_MODULE_MAP = _CPP_MODULE_MAP,
    LTO_INDEXING_OBJECT_FILE = _LTO_INDEXING_OBJECT_FILE,
)

def _artifact_category_info_init(name, default_prefix, *extensions):
    return {
        "allowed_extensions": extensions,
        "default_extension": extensions[0],
        "default_prefix": default_prefix,
        "name": name,
    }

# buildifier: disable=unused-variable
_ArtifactCategoryInfo, _unused_new_aci = provider(
    """A category of artifacts that are candidate input/output to an action, for
     which the toolchain can select a single artifact.""",
    fields = ["name", "default_prefix", "default_extension", "allowed_extensions"],
    init = _artifact_category_info_init,
)

# TODO: b/433485282 - remove duplicated extensions lists with above constants
_artifact_categories = [
    _ArtifactCategoryInfo("STATIC_LIBRARY", "lib", ".a", ".lib"),
    _ArtifactCategoryInfo("ALWAYSLINK_STATIC_LIBRARY", "lib", ".lo", ".lo.lib"),
    _ArtifactCategoryInfo("DYNAMIC_LIBRARY", "lib", ".so", ".dylib", ".dll", ".pyd", ".wasm", ".xll"),
    _ArtifactCategoryInfo("EXECUTABLE", "", "", ".exe", ".wasm"),
    _ArtifactCategoryInfo("INTERFACE_LIBRARY", "lib", ".ifso", ".tbd", ".if.lib", ".lib"),
    _ArtifactCategoryInfo("PIC_FILE", "", ".pic"),
    _ArtifactCategoryInfo("INCLUDED_FILE_LIST", "", ".d"),
    _ArtifactCategoryInfo("SERIALIZED_DIAGNOSTICS_FILE", "", ".dia"),
    _ArtifactCategoryInfo("OBJECT_FILE", "", ".o", ".obj"),
    _ArtifactCategoryInfo("PIC_OBJECT_FILE", "", ".pic.o"),
    _ArtifactCategoryInfo("CPP_MODULE", "", ".pcm", ".gcm", ".ifc"),
    _ArtifactCategoryInfo("CPP_MODULES_INFO", "", ".CXXModules.json"),
    _ArtifactCategoryInfo("CPP_MODULES_DDI", "", ".ddi"),
    _ArtifactCategoryInfo("CPP_MODULES_MODMAP", "", ".modmap"),
    _ArtifactCategoryInfo("CPP_MODULES_MODMAP_INPUT", "", ".modmap.input"),
    _ArtifactCategoryInfo("GENERATED_ASSEMBLY", "", ".s", ".asm"),
    _ArtifactCategoryInfo("PROCESSED_HEADER", "", ".processed"),
    _ArtifactCategoryInfo("GENERATED_HEADER", "", ".h"),
    _ArtifactCategoryInfo("PREPROCESSED_C_SOURCE", "", ".i"),
    _ArtifactCategoryInfo("PREPROCESSED_CPP_SOURCE", "", ".ii"),
    _ArtifactCategoryInfo("COVERAGE_DATA_FILE", "", ".gcno"),
    # A matched-clif protobuf. Typically in binary format, but could be text
    # depending on the options passed to the clif_matcher.
    _ArtifactCategoryInfo("CLIF_OUTPUT_PROTO", "", ".opb"),
]

artifact_category_names = struct(**{ac.name: ac.name for ac in _artifact_categories})

output_subdirectories = struct(
    OBJS = "_objs",
    PIC_OBJS = "_pic_objs",
    DOTD_FILES = "_dotd",
    PIC_DOTD_FILES = "_pic_dotd",
    DIA_FILES = "_dia",
    PIC_DIA_FILES = "_pic_dia",
)

def should_create_per_object_debug_info(feature_configuration, cpp_configuration):
    return cpp_configuration.fission_active_for_current_compilation_mode() and \
           feature_configuration.is_enabled("per_object_debug_info")

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
    return get_relative_path(get_relative_path("external", repository), package)

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
    return get_relative_path(prefix, repository)

def is_stamping_enabled(ctx):
    """Returns the tri-state of whether to encode build information into the binary.

    Args:
        ctx: The rule context.

    Returns:
        (int) Possible values are:
        1: Always stamp the build information into the binary, even in [--nostamp][stamp] builds.
        This setting should be avoided, since it potentially kills remote caching for the binary and
        any downstream actions that depend on it.
        0: Always replace build information by constant values. This gives good build result caching.
        -1: Embedding of build information is controlled by the [--[no]stamp][stamp] flag.
    """
    if ctx.configuration.is_tool_configuration():
        return 0
    stamp = 0
    if hasattr(ctx.attr, "stamp"):
        stamp = ctx.attr.stamp
    return stamp

def should_stamp(ctx):
    """Returns whether stamping should actually be performed based on stamp attribute and config.

    Unlike is_stamping_enabled, this takes into account the --[no]stamp Blaze flag, so the return value is a boolean, not a tri-state.

    Args:
        ctx: The rule context.

    Returns:
        true if stamping should be performed, false otherwise.
    """
    stamping_tri_state = is_stamping_enabled(ctx)
    return False if ctx.configuration.is_tool_configuration() else (
        stamping_tri_state == 1 or (stamping_tri_state == -1 and ctx.configuration.stamp_binaries())
    )

def is_shared_library(file):
    return file.extension in ["so", "dylib", "dll", "pyd", "wasm", "tgt", "vpi", "xll"]

def is_versioned_shared_library(file):
    # Because regex matching can be slow, we first do a quick check for ".so." and ".dylib."
    # substring before risking the full-on regex match. This should eliminate the performance
    # hit on practically every non-qualifying file type.
    if ".so." not in file.basename and ".dylib." not in file.basename:
        return False
    return is_versioned_shared_library_extension_valid(file.basename)

def use_pic_for_binaries(cpp_config, feature_configuration):
    """
    Returns whether binaries must be compiled with position independent code.
    """
    return cpp_config.force_pic() or (
        feature_configuration.is_enabled("supports_pic") and
        (cpp_config.compilation_mode() != "opt" or feature_configuration.is_enabled("prefer_pic_for_opt_binaries"))
    )

def use_pic_for_dynamic_libs(cpp_config, feature_configuration):
    """Determines if we should apply -fPIC for this rule's C++ compilations.

    This determination is
    generally made by the global C++ configuration settings "needsPic" and "usePicForBinaries".
    However, an individual rule may override these settings by applying -fPIC" to its "nocopts"
    attribute. This allows incompatible rules to "opt out" of global PIC settings (see bug:
    "Provide a way to turn off -fPIC for targets that can't be built that way").

    Returns:
       true if this rule's compilations should apply -fPIC, false otherwise
    """
    return (cpp_config.force_pic() or
            feature_configuration.is_enabled("supports_pic"))

def get_relative_path(path_a, path_b):
    if is_path_absolute(path_b):
        return path_b
    return paths.normalize(paths.join(path_a, path_b))

def path_contains_up_level_references(path):
    return path.startswith("..") and (len(path) == 2 or path[2] == "/")

def root_relative_path(file):
    """Returns the path of `file` relative to its root.

    A Starlark implementation of `Artifact.getRootRelativePath()`.

    Args:
        file: (File) The file to get the root-relative path for.

    Returns:
        (str) The root-relative path of the file.
    """

    # This function matches Bazel's Artifact.getRootRelativePath() implementation bug-for-bug,
    # including the surprising behavior that the result starts with "external/<repo>/" for external
    # source files, but not for external generated files.
    if not file.is_source:
        # https://github.com/bazelbuild/bazel/blob/795af54db5c348af5ca8b2961a982b399206ea20/src/main/java/com/google/devtools/build/lib/actions/Artifact.java#L310
        return file.path[len(file.root.path) + 1:]

    # https://github.com/bazelbuild/bazel/blob/795af54db5c348af5ca8b2961a982b399206ea20/src/main/java/com/google/devtools/build/lib/actions/Artifact.java#L786
    short_path = file.short_path
    if not short_path.startswith("../"):
        return short_path

    # This is a file in an external repo, skip over the repo name.
    return short_path[short_path.index("/", 3) + 1:]
