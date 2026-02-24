# Copyright 2021 The Bazel Authors. All rights reserved.
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

"""Implementation of cc_shared_library"""

load("@com_google_protobuf//bazel/common:proto_info.bzl", "ProtoInfo")
load("//cc:find_cc_toolchain.bzl", "use_cc_toolchain")
load("//cc/common:cc_helper.bzl", "cc_helper")
load("//cc/common:cc_info.bzl", "CcInfo")
load("//cc/common:cc_shared_library_hint_info.bzl", "CcSharedLibraryHintInfo")
load("//cc/common:cc_shared_library_info.bzl", "CcSharedLibraryInfo")
load("//cc/common:semantics.bzl", "semantics")
load("//cc/private:graph_node_info.bzl", "GraphNodeInfo")
load(":cc_shared_library_impl.bzl", "cc_shared_library_impl")

# TODO(#5200): Add export_define to library_to_link and cc_library

# Add this as a tag to any target that can be linked by more than one
# cc_shared_library because it doesn't have static initializers or anything
# else that may cause issues when being linked more than once. This should be
# used sparingly after making sure it's safe to use.
LINKABLE_MORE_THAN_ONCE = "LINKABLE_MORE_THAN_ONCE"

def _graph_structure_aspect_impl(target, ctx):
    children = []

    attributes = dir(ctx.rule.attr)
    owners = [ctx.label]
    if CcSharedLibraryHintInfo in target:
        attributes = getattr(target[CcSharedLibraryHintInfo], "attributes", dir(ctx.rule.attr))
        owners = getattr(target[CcSharedLibraryHintInfo], "owners", [ctx.label])

    # Collect graph structure info from any possible deplike attribute. The aspect
    # itself applies across every deplike attribute (attr_aspects is *), so enumerate
    # over all attributes and consume GraphNodeInfo if available.
    for fieldname in attributes:
        deps = getattr(ctx.rule.attr, fieldname, None)
        if type(deps) == "list":
            for dep in deps:
                if type(dep) == "Target" and GraphNodeInfo in dep:
                    children.append(dep[GraphNodeInfo])
        elif type(deps) == "Target" and GraphNodeInfo in deps:
            children.append(deps[GraphNodeInfo])

    # TODO(bazel-team): Add flag to Bazel that can toggle the initialization of
    # linkable_more_than_once.
    linkable_more_than_once = False
    if hasattr(ctx.rule.attr, "tags"):
        for tag in ctx.rule.attr.tags:
            if tag == LINKABLE_MORE_THAN_ONCE:
                linkable_more_than_once = True
    return [GraphNodeInfo(
        owners = owners,
        children = children,
        linkable_more_than_once = linkable_more_than_once,
    )]

graph_structure_aspect = aspect(
    attr_aspects = ["*"],
    required_providers = [[CcInfo], [CcSharedLibraryHintInfo], [ProtoInfo]],
    required_aspect_providers = [[CcInfo], [CcSharedLibraryHintInfo]],
    implementation = _graph_structure_aspect_impl,
)

def _cc_shared_library_initializer(**kwargs):
    """Converts labels in exports_filter into canonical form relative to the current repository.

    This conversion can only be done in a macro as it requires access to the repository mapping of
    the repository containing the cc_shared_library target. This mapping is automatically
    applied to label attributes, but exports_filter is a list of strings attribute.
    """
    if "exports_filter" not in kwargs:
        return kwargs

    raw_exports_filter = kwargs["exports_filter"]
    if type(raw_exports_filter) != type([]):
        # TODO: Also canonicalize labels in selects once macros can operate on them.
        # https://github.com/bazelbuild/bazel/issues/14157
        return kwargs

    canonical_exports_filter = [
        str(native.package_relative_label(s))
        for s in raw_exports_filter
    ]
    return kwargs | {"exports_filter": canonical_exports_filter}

cc_shared_library = rule(
    implementation = cc_shared_library_impl,
    initializer = _cc_shared_library_initializer,
    doc = """
<p>It produces a shared library.</p>

<h4 id="cc_shard_library_examples">Example</h4>

<pre class="code">
cc_shared_library(
    name = "foo_shared",
    deps = [
        ":foo",
    ],
    dynamic_deps = [
        ":bar_shared",
    ],
    additional_linker_inputs = [
        ":foo.lds",
    ],
    user_link_flags = [
        "-Wl,--version-script=$(location :foo.lds)",
    ],
)
cc_library(
    name = "foo",
    srcs = ["foo.cc"],
    hdrs = ["foo.h"],
    deps = [
        ":bar",
        ":baz",
    ],
)
cc_shared_library(
    name = "bar_shared",
    shared_lib_name = "bar.so",
    deps = [":bar"],
)
cc_library(
    name = "bar",
    srcs = ["bar.cc"],
    hdrs = ["bar.h"],
)
cc_library(
    name = "baz",
    srcs = ["baz.cc"],
    hdrs = ["baz.h"],
)
</pre>

<p>In the example <code>foo_shared</code> statically links <code>foo</code>
and <code>baz</code>, the latter being a transitive dependency. It doesn't
link <code>bar</code> because it is already provided dynamically by the
<code>dynamic_dep</code> <code>bar_shared</code>.</p>

<p><code>foo_shared</code> uses a linker script *.lds file to control which
symbols should be exported. The <code>cc_shared_library</code> rule logic does
not control which symbols get exported, it only uses what is assumed to be
exported to give errors during analysis phase if two shared libraries export the
same targets.</p>

<p>Every direct dependency of <code>cc_shared_library</code> is assumed to be
exported. Therefore, Bazel assumes during analysis that <code>foo</code> is being
exported by <code>foo_shared</code>. <code>baz</code> is not assumed to be exported
by <code>foo_shared</code>. Every target matched by the <code>exports_filter</code>
is also assumed to be exported.</p>

<p>Every single <code>cc_library</code> in the example should appear at most in one
<code>cc_shared_library</code>. If we wanted to link <code>baz</code> also into
<code>bar_shared</code> we would need to add
<code>tags = ["LINKABLE_MORE_THAN_ONCE"]</code> to <code>baz</code>.</p>

<p>Due to the <code>shared_lib_name</code> attribute, the file produced by
<code>bar_shared</code> will have the name <code>bar.so</code> as opposed
to the name <code>libbar.so</code> that it would have by default on Linux.</p>

<h4 id="cc_shard_library_examples">Errors</h4>
<h5><code>Two shared libraries in dependencies export the same symbols.</code></h5>

<p>This will happen whenever you are creating a target with two different
<code>cc_shared_library</code> dependencies that export the same target. To fix this
you need to stop the libraries from being exported in one of the
<code>cc_shared_library</code> dependencies.</p>

<h5><code>Two shared libraries in dependencies link the same library statically</code></h5>

<p>This will happen whenever you are creating a new <code>cc_shared_library</code> with two
different <code>cc_shared_library</code> dependencies that link the same target statically.
Similar to the error with exports.</p>

<p>One way to fix this is to stop linking the library into one of the
<code>cc_shared_library</code> dependencies. At the same time, the one that still links it
needs to export the library so that the one not linking it keeps visibility to
the symbols. Another way is to pull out a third library that exports the target.
A third way is to tag the culprit <code>cc_library</code> with <code>LINKABLE_MORE_THAN_ONCE</code>
but this fix should be rare and you should absolutely make sure that the
<code>cc_library</code> is indeed safe to link more than once.</p>

<h5><code>'//foo:foo' is already linked statically in '//bar:bar' but not exported`</code></h5>

<p>This means that a library in the transitive closure of your <code>deps</code> is reachable
without going through one of the <code>cc_shared_library</code> dependencies but is already
linked into a different <code>cc_shared_library</code> in <code>dynamic_deps</code> and is not
exported.</p>

<p>The solution is to export it from the <code>cc_shared_library</code> dependency or pull out
a third <code>cc_shared_library</code> that exports it.</p>

<h5><code>Do not place libraries which only contain a precompiled dynamic library in deps.
</code></h5>

<p>If you have a precompiled dynamic library, this doesn't need to and cannot be
linked statically into the current <code>cc_shared_library</code> target that you are
currently creating. Therefore, it doesn't belong in <code>deps</code> of the
<code>cc_shared_library</code>. If this precompiled dynamic library is a dependency of one
of your <code>cc_libraries</code>, then the <code>cc_library</code> needs to depend on it
directly.</p>

<h5><code>Trying to export a library already exported by a different shared library</code></h5>

<p>You will see this error if on the current rule you are claiming to export a
target that is already being exported by one of your dynamic dependencies.</p>

<p>To fix this, remove the target from <code>deps</code> and just rely on it from the dynamic
dependency or make sure that the <code>exports_filter</code> doesn't catch this target.</p>""",
    attrs = {
        "additional_linker_inputs": attr.label_list(allow_files = True, doc = """
Any additional files that you may want to pass to the linker, for example, linker scripts.
You have to separately pass any linker flags that the linker needs in order to be aware
of this file. You can do so via the <code>user_link_flags</code> attribute."""),
        "shared_lib_name": attr.string(doc = """
By default cc_shared_library will use a name for the shared library output file based on
the target's name and the platform. This includes an extension and sometimes a prefix.
Sometimes you may not want the default name, for example, when loading C++ shared libraries
for Python the default lib* prefix is often not desired, in which case you can use this
attribute to choose a custom name."""),
        "dynamic_deps": attr.label_list(providers = [CcSharedLibraryInfo], doc = """
These are other <code>cc_shared_library</code> dependencies the current target depends on.

<p>
The <code>cc_shared_library</code> implementation will use the list of
<code>dynamic_deps</code> (transitively, i.e. also the <code>dynamic_deps</code> of the
current target's <code>dynamic_deps</code>) to decide which <code>cc_libraries</code> in
the transitive <code>deps</code> should not be linked in because they are already provided
by a different <code>cc_shared_library</code>.
</p>"""),
        "exports_filter": attr.string_list(doc = """
This attribute contains a list of targets that are claimed to be exported by the current
shared library.

<p>
Any target <code>deps</code> is already understood to be exported by the shared library.
This attribute should be used to list any targets that are exported by the shared library
but are transitive dependencies of <code>deps</code>.
</p>

<p>
Note that this attribute is not actually adding a dependency edge to those targets, the
dependency edge should instead be created by <code>deps</code>.The entries in this
attribute are just strings. Keep in mind that when placing a target in this attribute,
this is considered a claim that the shared library exports the symbols from that target.
The <code>cc_shared_library</code> logic  doesn't actually handle telling the linker which
symbols should be exported.
</p>

<p>The following syntax is allowed:</p>
<p><code>//foo:__pkg__</code> to account for any target in foo/BUILD</p>
<p><code>//foo:__subpackages__</code> to account for any target in foo/BUILD or any other
package below foo/ like foo/bar/BUILD</p>"""),
        "win_def_file": attr.label(allow_single_file = [".def"], doc = """
The Windows DEF file to be passed to linker.
<p>This attribute should only be used when Windows is the target platform.
It can be used to <a href="https://msdn.microsoft.com/en-us/library/d91k01sh.aspx">
export symbols</a> during linking a shared library.</p>"""),
        "roots": attr.label_list(providers = [CcInfo], aspects = [graph_structure_aspect]),
        "deps": attr.label_list(providers = [CcInfo], aspects = [graph_structure_aspect], doc = """
Top level libraries that will unconditionally be statically linked into the shared library
after being whole-archived.

<p>
Any transitive library dependency of these direct deps will be linked into this shared
library as long as they have not already been linked by a <code>cc_shared_library</code>
in <code>dynamic_deps</code>.</p>

<p>
During analysis, the rule implementation will consider any target listed in
<code>deps</code> as being exported by the shared library in order to give errors when
multiple <code>cc_shared_libraries</code> export the same targets. The rule implementation
does not take care of informing the linker about which symbols should be exported by the
shared object. The user should take care of this via linker scripts or visibility
declarations in the source code.</p>

<p>
The implementation will also trigger errors whenever the same library is linked statically
into more than one <code>cc_shared_library</code>. This can be avoided by adding
<code>"LINKABLE_MORE_THAN_ONCE"</code> to the <code>cc_library.tags</code> or by listing
the `cc_library` as an export of one of the shared libraries so that one can be made a
<code>dynamic_dep</code> of the other.
</p>"""),
        "static_deps": attr.string_list(),
        "user_link_flags": attr.string_list(doc = """
Any additional flags that you may want to pass to the linker. For example, to make the
linker aware of a linker script passed via additional_linker_inputs you can use the
following:

<pre><code class="lang-starlark">
 cc_shared_library(
    name = "foo_shared",
    additional_linker_inputs = select({
      "//src/conditions:linux": [
        ":foo.lds",
        ":additional_script.txt",
      ],
      "//conditions:default": []}),
    user_link_flags = select({
      "//src/conditions:linux": [
        "-Wl,-rpath,kittens",
        "-Wl,--version-script=$(location :foo.lds)",
        "-Wl,--script=$(location :additional_script.txt)",
      ],
      "//conditions:default": []}),
      ...
 )
</code></pre>"""),
        "_def_parser": semantics.get_def_parser(),
        "_impl_delegate": attr.label(
            default = Label("//cc/private/rules_impl/wrappers:cc_shared_library_impl_wrapper"),
            cfg = "exec",
        ),
    },  # buildifier: disable=unsorted-dict-items
    toolchains = use_cc_toolchain() + semantics.get_runtimes_toolchain(),
    fragments = ["cpp"] + semantics.additional_fragments(),
)

def dynamic_deps_initializer(**kwargs):
    """Initializes dynamic_deps_attrs

    Args:
        **kwargs: (dict)

    Returns:
        (dict)
    """
    if "dynamic_deps" in kwargs and cc_helper.is_non_empty_list_or_select(kwargs["dynamic_deps"], "dynamic_deps"):
        # Propagate an aspect if dynamic_deps attribute is specified.
        # Use += for lists rather than extend or append to allow for the case where deps
        # is a select.
        all_deps = []
        if "deps" in kwargs:
            all_deps += kwargs["deps"]

        if "linkshared" not in kwargs or not kwargs["linkshared"]:
            # The += [...] pattern below doesn't work if malloc or link_extra_lib are
            # themselves selects, but as of March 2024, there is no way to combine mixed
            # selects and these attributes usually point to label flags anyway.
            if "link_extra_lib" in kwargs:
                all_deps += [kwargs["link_extra_lib"]]  # buildifier: disable=list-append
            if "malloc" in kwargs:
                all_deps += [kwargs["malloc"]]  # buildifier: disable=list-append

        return kwargs | {"_deps_analyzed_by_graph_structure_aspect": all_deps}
    return kwargs

dynamic_deps_attrs = {
    "dynamic_deps": attr.label_list(
        allow_files = False,
        providers = [CcSharedLibraryInfo],
        doc = """
These are other <code>cc_shared_library</code> dependencies the current target depends on.

<p>
The <code>cc_shared_library</code> implementation will use the list of
<code>dynamic_deps</code> (transitively, i.e. also the <code>dynamic_deps</code> of the
current target's <code>dynamic_deps</code>) to decide which <code>cc_libraries</code> in
the transitive <code>deps</code> should not be linked in because they are already provided
by a different <code>cc_shared_library</code>.
        """ + semantics.dynamic_deps_extra_docs,
    ),
    "_deps_analyzed_by_graph_structure_aspect": attr.label_list(
        providers = [CcInfo],
        aspects = [graph_structure_aspect],
    ),
}
