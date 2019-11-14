"""This is an experimental implementation of cc_shared_library.

We may change the implementation at any moment or even delete this file. Do not
rely on this. It requires bazel >1.2  and passing the flag
--experimental_cc_shared_library
"""

load("//cc:find_cc_toolchain.bzl", "find_cc_toolchain")

# TODO(#5200): Add export_define to library_to_link and cc_library

GraphNodeInfo = provider(
    fields = {
        "children": "Other GraphNodeInfo from dependencies of this target",
        "label": "Label of the target visited",
        "linked_statically_by": "The value of this attribute if the target has it",
    },
)
CcSharedLibraryInfo = provider(
    fields = {
        "dynamic_deps": "All shared libraries depended on transitively",
        "linker_input": "the resulting linker input artifact for the shared library",
        "exports": "cc_libraries that are linked statically and exported",
    },
)

def _separate_static_and_dynamic_link_libraries(direct_children, can_be_linked_dynamically):
    node = None
    all_children = list(direct_children)
    link_statically_labels = {}
    link_dynamically_labels = {}

    # Horrible I know. Perhaps Starlark team gives me a way to prune a tree.
    for i in range(1, 2147483647):
        if len(all_children) == 0:
            break
        node = all_children.pop(0)

        if node.label in can_be_linked_dynamically:
            link_dynamically_labels[node.label] = None
        else:
            link_statically_labels[node.label] = node.linked_statically_by
            all_children.extend(node.children)
    return (link_statically_labels, link_dynamically_labels)

def _create_linker_context(ctx, static_linker_inputs, dynamic_linker_inputs):
    linker_inputs = []
    linker_inputs.extend(dynamic_linker_inputs)
    linker_inputs.extend(static_linker_inputs)

    return cc_common.create_linking_context(
        linker_inputs = depset(linker_inputs),
    )

def _merge_cc_shared_library_infos(ctx):
    dynamic_deps = []
    transitive_dynamic_deps = []
    for dep in ctx.attr.dynamic_deps:
        dynamic_dep_entry = (
            dep[CcSharedLibraryInfo].exports,
            dep[CcSharedLibraryInfo].linker_input,
        )
        dynamic_deps.append(dynamic_dep_entry)
        transitive_dynamic_deps.append(dep[CcSharedLibraryInfo].dynamic_deps)

    return depset(direct = dynamic_deps, transitive = transitive_dynamic_deps)

def _build_exports_map_from_only_dynamic_deps(merged_shared_library_infos):
    exports_map = {}
    for entry in merged_shared_library_infos.to_list():
        exports = entry[0]
        linker_input = entry[1]
        for export in exports:
            str_export_label = str(export.label)
            if str_export_label in exports_map:
                fail("Two shared libraries in dependencies export the same symbols. Both " +
                     exports_map[str_export_label].libraries[0].dynamic_library.short_path +
                     " and " + linker_input.dynamic_library.short_path +
                     " export " + str_export_label)
            exports_map[str(export.label)] = linker_input
    return exports_map

def _filter_inputs(ctx, transitive_exports):
    static_linker_inputs = []
    dynamic_linker_inputs = []

    graph_structure_aspect_nodes = []
    linker_inputs = []
    for export in ctx.attr.exports:
        linker_inputs.extend(export[CcInfo].linking_context.linker_inputs.to_list())
        graph_structure_aspect_nodes.append(export[GraphNodeInfo])

    can_be_linked_dynamically = {}
    for linker_input in linker_inputs:
        owner = str(linker_input.owner)
        if owner in transitive_exports:
            can_be_linked_dynamically[owner] = True

    (link_statically_labels, link_dynamically_labels) = _separate_static_and_dynamic_link_libraries(
        graph_structure_aspect_nodes,
        can_be_linked_dynamically,
    )

    already_linked_dynamically = {}
    for linker_input in linker_inputs:
        owner = str(linker_input.owner)
        if owner in link_dynamically_labels:
            dynamic_linker_input = transitive_exports[owner]
            if str(dynamic_linker_input.owner) not in already_linked_dynamically:
                already_linked_dynamically[str(dynamic_linker_input.owner)] = True
                dynamic_linker_inputs.append(dynamic_linker_input)
        elif owner in link_statically_labels:
            can_be_linked_statically = False
            for linked_statically_by in link_statically_labels[owner]:
                if linked_statically_by == str(ctx.label):
                    can_be_linked_statically = True
                    static_linker_inputs.append(linker_input)
                    break
            if not can_be_linked_statically:
                fail("We can't link " +
                     str(owner) + " either statically or dynamically")
        else:
            fail("Implementation error, this should not happen")

    # Every direct dynamic_dep of this rule will be linked dynamically even if we
    # didn't reach a cc_library exported by one of these dynamic_deps. In other
    # words, the shared library might link more shared libraries than we need
    # in the cc_library graph.
    for dep in ctx.attr.dynamic_deps:
        has_a_used_export = False
        for export in dep[CcSharedLibraryInfo].exports:
            if str(export.label) in link_dynamically_labels:
                has_a_used_export = True
                break
        if not has_a_used_export:
            dynamic_linker_inputs.append(dep[CcSharedLibraryInfo].linker_input)

    return (static_linker_inputs, dynamic_linker_inputs)

def _cc_shared_library_impl(ctx):
    cc_toolchain = find_cc_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )

    merged_cc_shared_library_info = _merge_cc_shared_library_infos(ctx)
    exports_map = _build_exports_map_from_only_dynamic_deps(merged_cc_shared_library_info)
    for export in ctx.attr.exports:
        if str(export.label) in exports_map:
            fail("Trying to export a library already exported by a different shared library: " + str(export.label))
    (static_linker_inputs, dynamic_linker_inputs) = _filter_inputs(ctx, exports_map)

    linking_context = _create_linker_context(ctx, static_linker_inputs, dynamic_linker_inputs)

    user_link_flags = []
    additional_inputs = []
    if ctx.file.visibility_file != None:
        user_link_flags = [
            "-Wl,--no-undefined",  # Just here for testing.
            "-Wl,--version-script=" + ctx.file.visibility_file.path,
        ]
        additional_inputs = [ctx.file.visibility_file]

    linking_outputs = cc_common.link(
        actions = ctx.actions,
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        linking_contexts = [linking_context],
        user_link_flags = user_link_flags,
        additional_inputs = additional_inputs,
        name = ctx.label.name,
        output_type = "dynamic_library",
    )

    return [
        DefaultInfo(files = depset([linking_outputs.library_to_link.resolved_symlink_dynamic_library])),
        CcSharedLibraryInfo(
            dynamic_deps = merged_cc_shared_library_info,
            exports = ctx.attr.exports,
            linker_input = cc_common.create_linker_input(
                owner = ctx.label,
                libraries = depset([linking_outputs.library_to_link]),
            ),
        ),
    ]

def _graph_structure_aspect_impl(target, ctx):
    children = []

    if hasattr(ctx.rule.attr, "deps"):
        for dep in ctx.rule.attr.deps:
            if GraphNodeInfo in dep:
                children.append(dep[GraphNodeInfo])

    linked_statically_by = []
    if hasattr(ctx.rule.attr, "linked_statically_by"):
        linked_statically_by = ctx.rule.attr.linked_statically_by

    return [GraphNodeInfo(
        label = str(ctx.label),
        linked_statically_by = linked_statically_by,
        children = children,
    )]

graph_structure_aspect = aspect(
    attr_aspects = ["*"],
    implementation = _graph_structure_aspect_impl,
)

cc_shared_library = rule(
    implementation = _cc_shared_library_impl,
    attrs = {
        "dynamic_deps": attr.label_list(providers = [CcSharedLibraryInfo]),
        "visibility_file": attr.label(allow_single_file = True),
        "exports": attr.label_list(aspects = [graph_structure_aspect]),
        "_cc_toolchain": attr.label(default = "@bazel_tools//tools/cpp:current_cc_toolchain"),
    },
    toolchains = ["//cc:toolchain_type"],
    fragments = ["cpp"],
)
