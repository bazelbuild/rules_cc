
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "CPP_LINK_STATIC_LIBRARY_ACTION_NAME")

def cc_library_func(ctx, name, hdrs, srcs, deps):
    """Creates compile/link actions like cc_library()

    This function is a higher-level alternative to the C++ Sandwich API.
    This API will stay stable even as the lower-level sandwich APIs change.

    Args:
      ctx: Rule context object.
      hdrs: public headers (array of File objects).
      srcs: sources and private headers (array of File objects).
      deps: rules with CcInfo providers that we compile/link against.

    Returns:
      CcInfo provider.
    """

    compilation_contexts = []
    cc_infos = []
    for dep in deps:
        if CcInfo in dep:
            cc_info = dep[CcInfo]
            cc_infos.append(cc_info)
            compilation_contexts.append(dep[CcInfo].compilation_context)
    toolchain = find_cpp_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        cc_toolchain = toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    compilation_info = cc_common.compile(
        ctx = ctx,
        feature_configuration = feature_configuration,
        cc_toolchain = toolchain,
        srcs = srcs,
        hdrs = hdrs,
        compilation_contexts = compilation_contexts,
    )
    output_file = ctx.new_file(ctx.bin_dir, "lib" + name + ".a")
    library_to_link = cc_common.create_library_to_link(
        actions = ctx.actions,
        feature_configuration = feature_configuration,
        cc_toolchain = toolchain,
        static_library = output_file,
    )
    archiver_path = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = CPP_LINK_STATIC_LIBRARY_ACTION_NAME,
    )
    archiver_variables = cc_common.create_link_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = toolchain,
        output_file = output_file.path,
        is_using_linker = False,
    )
    command_line = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = CPP_LINK_STATIC_LIBRARY_ACTION_NAME,
        variables = archiver_variables,
    )

    # Non-PIC objects only get emitted in opt builds.
    use_pic = True
    if ctx.var.get("COMPILATION_MODE") == "opt":
        use_pic = False

    object_files = compilation_info.cc_compilation_outputs.object_files(use_pic = use_pic)
    args = ctx.actions.args()
    args.add_all(command_line)
    args.add_all(object_files)

    env = cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = CPP_LINK_STATIC_LIBRARY_ACTION_NAME,
        variables = archiver_variables,
    )

    ctx.actions.run(
        executable = archiver_path,
        arguments = [args],
        env = env,
        inputs = depset(
            direct = object_files,
            transitive = [
                # TODO: Use CcToolchainInfo getters when available
                # See https://github.com/bazelbuild/bazel/issues/7427.
                ctx.attr._cc_toolchain.files,
            ],
        ),
        outputs = [output_file],
    )
    linking_context = cc_common.create_linking_context(
        libraries_to_link = [library_to_link],
    )
    info = CcInfo(
        compilation_context = compilation_info.compilation_context,
        linking_context = linking_context,
    )
    return cc_common.merge_cc_infos(cc_infos = [info] + cc_infos)
