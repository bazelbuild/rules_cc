load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")

CcSharedLibraryInfo = provider()

def _get_all_labels(direct_children):
    node = None
    all_children = list(direct_children)
    all_labels = {}
    for i in range(1, 2147483647):
        if len(all_children) == 0:
            break
        node = all_children.pop(0)

        all_labels[node.label] = True

        all_children.extend(node.children)
    return all_labels

def _get_dynamic_libraries(ctx, all_labels):
    direct_cc_shared_library_infos = []
    for direct_dynamic_dep in ctx.attr.dynamic_deps:
        cc_shared_library_info = direct_dynamic_dep[CcSharedLibraryInfo]
        direct_cc_shared_library_infos.append(cc_shared_library_info)

    dynamic_labels = {}
    cc_shared_library_infos = list(direct_cc_shared_library_infos)
    dynamic_libraries = []
    for i in range(1, 2147483647):
        if len(cc_shared_library_infos) == 0:
            break
        cc_shared_library_info = cc_shared_library_infos.pop(0)
        dynamic_labels[cc_shared_library_info.of] = True
        dynamic_libraries.append(cc_shared_library_info.transitive_library)
        for direct_cc_shared_library_info in cc_shared_library_info.direct_cc_shared_library_infos:
            if direct_cc_shared_library_info.of in all_labels:
                cc_shared_library_infos.append(direct_cc_shared_library_info)

    return (direct_cc_shared_library_infos, dynamic_labels, dynamic_libraries)

def _get_whitelisted_labels(direct_children, dynamic_labels):
    whitelisted_labels = {}
    whitelisted_children = list(direct_children)
    for i in range(1, 2147483647):
        if len(whitelisted_children) == 0:
            break
        node = whitelisted_children.pop(0)

        whitelisted_labels[node.label] = True

        for child in node.children:
            if child.label not in dynamic_labels:
                whitelisted_children.append(child)

    return whitelisted_labels

def _get_new_linking_context(cc_info, dynamic_libraries, whitelisted_labels):
    libraries_to_link = []
    for library_to_link in cc_info.linking_context.libraries_to_link.to_list():
        if library_to_link.label in whitelisted_labels:
            libraries_to_link.append(library_to_link)

    libraries_to_link.extend(dynamic_libraries)

    return cc_common.create_linking_context(
        libraries_to_link = libraries_to_link,
        user_link_flags = cc_info.linking_context.user_link_flags,
        additional_inputs = cc_info.linking_context.additional_inputs.to_list(),
    )

def _get_version_script(ctx, new_linking_context, export_labels):
    libraries_to_link = new_linking_context.libraries_to_link
    objects = []
    exports = {}
    for export_label in export_labels:
        exports[export_label.label] = True

    for library_to_link in libraries_to_link.to_list():
        if library_to_link.label in exports:
            if library_to_link.objects != None:
                objects.extend(library_to_link.objects)
            elif library_to_link.pic_objects != None:
                objects.extend(library_to_link.pic_objects)

    symbols_file = ctx.actions.declare_file(ctx.label.name + "_symbols.txt")
    arguments = [symbols_file.path]
    for object_file in objects:
        arguments.append(object_file.path)

    ctx.actions.run(
        outputs = [symbols_file],
        inputs = objects,
        executable = ctx.executable._symbol_grabber,
        arguments = arguments,
    )

    return symbols_file

GraphNodeInfo = provider()

def _graph_structure_aspect_impl(target, ctx):
    children = []

    # TODO: We should actually check every attribute, not just deps or of, with the
    # exception of those which don't have CcInfo.
    if hasattr(ctx.rule.attr, "deps"):
        for dep in ctx.rule.attr.deps:
            if GraphNodeInfo in dep:
                children.append(dep[GraphNodeInfo])
    if hasattr(ctx.rule.attr, "of"):
        children.append(ctx.rule.attr.of[GraphNodeInfo])

    return [GraphNodeInfo(label = ctx.label, children = children)]

graph_structure_aspect = aspect(
    attr_aspects = ["*"],
    implementation = _graph_structure_aspect_impl,
)

def _cc_shared_library_impl(ctx):
    of_graph_node_info = ctx.attr.of[GraphNodeInfo]
    all_labels = _get_all_labels([of_graph_node_info])

    (direct_cc_shared_library_infos, dynamic_labels, dynamic_libraries) = _get_dynamic_libraries(ctx, all_labels)

    whitelisted_labels = _get_whitelisted_labels([of_graph_node_info], dynamic_labels)

    new_linking_context = _get_new_linking_context(ctx.attr.of[CcInfo], dynamic_libraries, whitelisted_labels)

    cc_toolchain = find_cpp_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    symbols = _get_version_script(ctx, new_linking_context, [ctx.attr.of])

    linking_outputs = cc_common.link(
        actions = ctx.actions,
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        linking_contexts = [new_linking_context],
        user_link_flags = ["-Wl,--version-script=" + symbols.path],
        additional_inputs = [symbols],
        name = ctx.label.name,
        output_type = "dynamic_library",
    )
    transitive_library = linking_outputs.library_to_link

    return [
        DefaultInfo(files = depset([transitive_library.resolved_symlink_dynamic_library, symbols])),
        CcSharedLibraryInfo(
            of = ctx.attr.of[GraphNodeInfo].label,
            compilation_context = ctx.attr.of[CcInfo].compilation_context,
            transitive_library = transitive_library,
            direct_cc_shared_library_infos = direct_cc_shared_library_infos,
        ),
    ]

cc_shared_library = rule(
    implementation = _cc_shared_library_impl,
    attrs = {
        "of": attr.label(aspects = [graph_structure_aspect]),
        "dynamic_deps": attr.label_list(providers = [CcSharedLibraryInfo]),
        "preloaded_deps": attr.label_list(providers = [CcInfo]),
        "export_all": attr.bool(),
        "export_wrapped_library": attr.bool(),
        "additional_symbols_to_export": attr.label(allow_single_file = True),
        "_cc_toolchain": attr.label(default = "@bazel_tools//tools/cpp:current_cc_toolchain"),
        "_symbol_grabber": attr.label(default = ":symbol_grabber", executable = True, cfg = "host"),
    },
    fragments = ["google_cpp", "cpp"],
)

def _cc_bin_impl(ctx):
    cc_toolchain = find_cpp_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )

    direct_children = []
    cc_infos = []
    compilation_contexts = []
    for dep in ctx.attr.deps:
        if GraphNodeInfo in dep:
            direct_children.append(dep[GraphNodeInfo])
        if CcInfo in dep:
            compilation_contexts.append(dep[CcInfo].compilation_context)
            cc_infos.append(dep[CcInfo])

    for dep in ctx.attr.dynamic_deps:
        if GraphNodeInfo in dep:
            direct_children.append(dep[GraphNodeInfo])
        if CcInfo in dep:
            compilation_contexts.append(dep[CcInfo].compilation_context)
            cc_infos.append(dep[CcInfo])

    all_labels = _get_all_labels(direct_children)

    (direct_cc_shared_library_infos, dynamic_labels, dynamic_libraries) = _get_dynamic_libraries(ctx, all_labels)

    for direct_cc_shared_library_info in direct_cc_shared_library_infos:
        compilation_contexts.append(direct_cc_shared_library_info.compilation_context)

    merged_cc_info = cc_common.merge_cc_infos(cc_infos = cc_infos)

    (_compilation_context, compilation_outputs) = cc_common.compile(
        name = ctx.label.name,
        actions = ctx.actions,
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        srcs = ctx.files.srcs,
        compilation_contexts = compilation_contexts,
    )

    whitelisted_children = []
    for child in direct_children:
        if child.label in dynamic_labels:
            fail("From cc_binary, do not depend on the same library statically and dynamically")
        whitelisted_children.append(child)

    whitelisted_labels = _get_whitelisted_labels(whitelisted_children, dynamic_labels)

    new_linking_context = _get_new_linking_context(merged_cc_info, dynamic_libraries, whitelisted_labels)

    linking_outputs = cc_common.link(
        name = ctx.label.name,
        actions = ctx.actions,
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        compilation_outputs = compilation_outputs,
        linking_contexts = [new_linking_context],
        link_deps_statically = ctx.attr.linkstatic,
    )
    files = [linking_outputs.executable]
    runfiles = []
    for library in dynamic_libraries:
        runfiles.append(library.dynamic_library)

    return [
        DefaultInfo(
            files = depset(files),
            runfiles = ctx.runfiles(files = runfiles),
        ),
    ]

cc_bin = rule(
    implementation = _cc_bin_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = [".cc"]),
        "deps": attr.label_list(
            allow_empty = True,
            providers = [CcInfo],
        ),
        "data": attr.label_list(
            default = [],
            allow_files = True,
        ),
        "dynamic_deps": attr.label_list(
            providers = [CcSharedLibraryInfo],
            aspects = [graph_structure_aspect],
        ),
        "linkstatic": attr.bool(default = True),
        "_cc_toolchain": attr.label(default = "@bazel_tools//tools/cpp:current_cc_toolchain"),
    },
    fragments = ["google_cpp", "cpp"],
)
