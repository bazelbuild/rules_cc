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

"""cc_library Starlark declaration replacing native"""

load("//cc:find_cc_toolchain.bzl", "use_cc_toolchain")
load("//cc/common:cc_info.bzl", "CcInfo")
load("//cc/common:semantics.bzl", "semantics")
load(":attrs.bzl", "common_attrs", "linkstatic_doc")
load(":cc_library_impl.bzl", "cc_library_impl")

LINKER_SCRIPT = [".ld", ".lds", ".ldscript"]
PREPROCESSED_C = [".i"]
DEPS_ALLOWED_RULES = [
    "genrule",
    "cc_library",
    "cc_inc_library",
    "cc_embed_data",
    "go_library",
    "objc_library",
    "cc_import",
    "cc_proto_library",
    "gentpl",
    "gentplvars",
    "genantlr",
    "sh_library",
    "cc_binary",
    "cc_test",
]

cc_library = rule(
    implementation = cc_library_impl,
    doc = """
<p>Use <code>cc_library()</code> for C++-compiled libraries.
  The result is  either a <code>.so</code>, <code>.lo</code>,
  or <code>.a</code>, depending on what is needed.
</p>

<p>
  If you build something with static linking that depends on
  a <code>cc_library</code>, the output of a depended-on library rule
  is the <code>.a</code> file. If you specify
   <code>alwayslink=True</code>, you get the <code>.lo</code> file.
</p>

<p>
  The actual output file name is <code>lib<i>foo</i>.so</code> for
  the shared library, where <i>foo</i> is the name of the rule.  The
  other kinds of libraries end with <code>.lo</code> and <code>.a</code>,
  respectively.  If you need a specific shared library name, for
  example, to define a Python module, use a genrule to copy the library
  to the desired name.
</p>

<h4 id="hdrs">Header inclusion checking</h4>

<p>
  All header files that are used in the build must be declared in
  the <code>hdrs</code> or <code>srcs</code> of <code>cc_*</code> rules.
  This is enforced.
</p>

<p>
  For <code>cc_library</code> rules, headers in <code>hdrs</code> comprise the
  public interface of the library and can be directly included both
  from the files in <code>hdrs</code> and <code>srcs</code> of the library
  itself as well as from files in <code>hdrs</code> and <code>srcs</code>
  of <code>cc_*</code> rules that list the library in their <code>deps</code>.
  Headers in <code>srcs</code> must only be directly included from the files
  in <code>hdrs</code> and <code>srcs</code> of the library itself. When
  deciding whether to put a header into <code>hdrs</code> or <code>srcs</code>,
  you should ask whether you want consumers of this library to be able to
  directly include it. This is roughly the same decision as
  between <code>public</code> and <code>private</code> visibility in programming languages.
</p>

<p>
  <code>cc_binary</code> and <code>cc_test</code> rules do not have an exported
  interface, so they also do not have a <code>hdrs</code> attribute. All headers
  that belong to the binary or test directly should be listed in
  the <code>srcs</code>.
</p>

<p>
  To illustrate these rules, look at the following example.
</p>

<pre><code class="lang-starlark">
cc_binary(
    name = "foo",
    srcs = [
        "foo.cc",
        "foo.h",
    ],
    deps = [":bar"],
)

cc_library(
    name = "bar",
    srcs = [
        "bar.cc",
        "bar-impl.h",
    ],
    hdrs = ["bar.h"],
    deps = [":baz"],
)

cc_library(
    name = "baz",
    srcs = [
        "baz.cc",
        "baz-impl.h",
    ],
    hdrs = ["baz.h"],
)
</code></pre>

<p>
  The allowed direct inclusions in this example are listed in the table below.
  For example <code>foo.cc</code> is allowed to directly
  include <code>foo.h</code> and <code>bar.h</code>, but not <code>baz.h</code>.
</p>

<table class="table table-striped table-bordered table-condensed">
  <thead>
    <tr><th>Including file</th><th>Allowed inclusions</th></tr>
  </thead>
  <tbody>
    <tr><td>foo.h</td><td>bar.h</td></tr>
    <tr><td>foo.cc</td><td>foo.h bar.h</td></tr>
    <tr><td>bar.h</td><td>bar-impl.h baz.h</td></tr>
    <tr><td>bar-impl.h</td><td>bar.h baz.h</td></tr>
    <tr><td>bar.cc</td><td>bar.h bar-impl.h baz.h</td></tr>
    <tr><td>baz.h</td><td>baz-impl.h</td></tr>
    <tr><td>baz-impl.h</td><td>baz.h</td></tr>
    <tr><td>baz.cc</td><td>baz.h baz-impl.h</td></tr>
  </tbody>
</table>

<p>
  The inclusion checking rules only apply to <em>direct</em>
  inclusions. In the example above <code>foo.cc</code> is allowed to
  include <code>bar.h</code>, which may include <code>baz.h</code>, which in
  turn is allowed to include <code>baz-impl.h</code>. Technically, the
  compilation of a <code>.cc</code> file may transitively include any header
  file in the <code>hdrs</code> or <code>srcs</code> in
  any <code>cc_library</code> in the transitive <code>deps</code> closure. In
  this case the compiler may read <code>baz.h</code> and <code>baz-impl.h</code>
  when compiling <code>foo.cc</code>, but <code>foo.cc</code> must not
  contain <code>#include "baz.h"</code>. For that to be
  allowed, <code>baz</code> must be added to the <code>deps</code>
  of <code>foo</code>.
</p>

<p>
  Bazel depends on toolchain support to enforce the inclusion checking rules.
  The <code>layering_check</code> feature has to be supported by the toolchain
  and requested explicitly, for example via the
  <code>--features=layering_check</code> command-line flag or the
  <code>features</code> parameter of the
  <a href="${link package}"><code>package</code></a> function. The toolchains
  provided by Bazel only support this feature with clang on Unix and macOS.
</p>

<h4 id="cc_library_examples">Examples</h4>

<p id="alwayslink_lib_example">
   We use the <code>alwayslink</code> flag to force the linker to link in
   this code although the main binary code doesn't reference it.
</p>

<pre><code class="lang-starlark">
cc_library(
    name = "ast_inspector_lib",
    srcs = ["ast_inspector_lib.cc"],
    hdrs = ["ast_inspector_lib.h"],
    visibility = ["//visibility:public"],
    deps = ["//third_party/llvm/llvm/tools/clang:frontend"],
    # alwayslink as we want to be able to call things in this library at
    # debug time, even if they aren't used anywhere in the code.
    alwayslink = True,
)
</code></pre>


<p>The following example comes from
   <code>third_party/python2_4_3/BUILD</code>.
   Some of the code uses the <code>dl</code> library (to load
   another, dynamic library), so this
   rule specifies the <code>-ldl</code> link option to link the
   <code>dl</code> library.
</p>

<pre><code class="lang-starlark">
cc_library(
    name = "python2_4_3",
    linkopts = [
        "-ldl",
        "-lutil",
    ],
    deps = ["//third_party/expat"],
)
</code></pre>

<p>The following example comes from <code>third_party/kde/BUILD</code>.
   We keep pre-built <code>.so</code> files in the depot.
   The header files live in a subdirectory named <code>include</code>.
</p>

<pre><code class="lang-starlark">
cc_library(
    name = "kde",
    srcs = [
        "lib/libDCOP.so",
        "lib/libkdesu.so",
        "lib/libkhtml.so",
        "lib/libkparts.so",
        <var>...more .so files...</var>,
    ],
    includes = ["include"],
    deps = ["//third_party/X11"],
)
</code></pre>

<p>The following example comes from <code>third_party/gles/BUILD</code>.
   Third-party code often needs some <code>defines</code> and
   <code>linkopts</code>.
</p>

<pre><code class="lang-starlark">
cc_library(
    name = "gles",
    srcs = [
        "GLES/egl.h",
        "GLES/gl.h",
        "ddx.c",
        "egl.c",
    ],
    defines = [
        "USE_FLOAT",
        "__GL_FLOAT",
        "__GL_COMMON",
    ],
    linkopts = ["-ldl"],  # uses dlopen(), dl library
    deps = [
        "es",
        "//third_party/X11",
    ],
)
</code></pre>
""",
    # buildifier: disable=unsorted-dict-items
    attrs = common_attrs | {
        "hdrs": attr.label_list(
            allow_files = True,
            flags = ["ORDER_INDEPENDENT", "DIRECT_COMPILE_TIME_INPUT"],
            doc = """
The list of header files published by
this library to be directly included by sources in dependent rules.
<p>This is the strongly preferred location for declaring header files that
 describe the interface for the library. These headers will be made
 available for inclusion by sources in this rule or in dependent rules.
 Headers not meant to be included by a client of this library should be
 listed in the <code>srcs</code> attribute instead, even if they are
 included by a published header. See <a href="#hdrs">"Header inclusion
 checking"</a> for a more detailed description. </p>
<p>Permitted <code>headers</code> file types:
  <code>.h</code>,
  <code>.hh</code>,
  <code>.hpp</code>,
  <code>.hxx</code>.
</p>
        """,
        ),
        "textual_hdrs": attr.label_list(
            allow_files = True,
            flags = ["ORDER_INDEPENDENT", "DIRECT_COMPILE_TIME_INPUT"],
            doc = """
The list of header files published by
this library to be textually included by sources in dependent rules.
<p>This is the location for declaring header files that cannot be compiled on their own;
 that is, they always need to be textually included by other source files to build valid
 code.</p>
""",
        ),
        "deps": attr.label_list(
            providers = [CcInfo],
            flags = ["SKIP_ANALYSIS_TIME_FILETYPE_CHECK"],
            allow_files = LINKER_SCRIPT + PREPROCESSED_C,
            allow_rules = DEPS_ALLOWED_RULES,
            doc = """
The list of other libraries that the library target depends upon.

<p>These can be <code>cc_library</code> or <code>objc_library</code> targets.</p>

<p>See general comments about <code>deps</code>
  at <a href="${link common-definitions#typical-attributes}">Typical attributes defined by
  most build rules</a>.
</p>
<p>These should be names of C++ library rules.
   When you build a binary that links this rule's library,
   you will also link the libraries in <code>deps</code>.
</p>
<p>Despite the "deps" name, not all of this library's clients
   belong here.  Run-time data dependencies belong in <code>data</code>.
   Source files generated by other rules belong in <code>srcs</code>.
</p>
<p>To link in a pre-compiled third-party library, add its name to
   the <code>srcs</code> instead.
</p>
<p>To depend on something without linking it to this library, add its
   name to the <code>data</code> instead.
</p>
""",
        ),
        "implementation_deps": attr.label_list(providers = [CcInfo], allow_files = False, doc = """
The list of other libraries that the library target depends on. Unlike with
<code>deps</code>, the headers and include paths of these libraries (and all their
transitive deps) are only used for compilation of this library, and not libraries that
depend on it. Libraries specified with <code>implementation_deps</code> are still linked in
binary targets that depend on this library.
"""),
        "strip_include_prefix": attr.string(doc = """
The prefix to strip from the paths of the headers of this rule.

<p>When set, the headers in the <code>hdrs</code> attribute of this rule are accessible
at their path with this prefix cut off.

<p>If it's a relative path, it's taken as a package-relative one. If it's an absolute one,
it's understood as a repository-relative path.

<p>The prefix in the <code>include_prefix</code> attribute is added after this prefix is
stripped.

<p>This attribute is only legal under <code>third_party</code>.
"""),
        "include_prefix": attr.string(doc = """
The prefix to add to the paths of the headers of this rule.

<p>When set, the headers in the <code>hdrs</code> attribute of this rule are accessible
at is the value of this attribute prepended to their repository-relative path.

<p>The prefix in the <code>strip_include_prefix</code> attribute is removed before this
prefix is added.

<p>This attribute is only legal under <code>third_party</code>.
"""),
        "alwayslink": attr.bool(default = False, doc = """
If 1, any binary that depends (directly or indirectly) on this C++
library will link in all the object files for the files listed in
<code>srcs</code>, even if some contain no symbols referenced by the binary.
This is useful if your code isn't explicitly called by code in
the binary, e.g., if your code registers to receive some callback
provided by some service.

<p>If alwayslink doesn't work with VS 2017 on Windows, that is due to a
<a href="https://github.com/bazelbuild/bazel/issues/3949">known issue</a>,
please upgrade your VS 2017 to the latest version.</p>
"""),
        "linkstatic": attr.bool(default = False, doc = linkstatic_doc),
        "linkstamp": attr.label(allow_single_file = True, doc = """
Simultaneously compiles and links the specified C++ source file into the final
binary. This trickery is required to introduce timestamp
information into binaries; if we compiled the source file to an
object file in the usual way, the timestamp would be incorrect.
A linkstamp compilation may not include any particular set of
compiler flags and so should not depend on any particular
header, compiler option, or other build variable.
<em class='harmful'>This option should only be needed in the
<code>base</code> package.</em>
"""),
        "linkopts": attr.string_list(doc = """
See <a href="${link cc_binary.linkopts}"><code>cc_binary.linkopts</code></a>.
The <code>linkopts</code> attribute is also applied to any target that
depends, directly or indirectly, on this library via <code>deps</code>
attributes (or via other attributes that are treated similarly:
the <a href="${link cc_binary.malloc}"><code>malloc</code></a>
attribute of <a href="${link cc_binary}"><code>cc_binary</code></a>). Dependency
linkopts take precedence over dependent linkopts (i.e. dependency linkopts
appear later in the command line). Linkopts specified in
<a href='../user-manual.html#flag--linkopt'><code>--linkopt</code></a>
take precedence over rule linkopts.
</p>
<p>
Note that the <code>linkopts</code> attribute only applies
when creating <code>.so</code> files or executables, not
when creating <code>.a</code> or <code>.lo</code> files.
So if the <code>linkstatic=True</code> attribute is set, the
<code>linkopts</code> attribute has no effect on the creation of
this library, only on other targets which depend on this library.
</p>
<p>
Also, it is important to note that "-Wl,-soname" or "-Xlinker -soname"
options are not supported and should never be specified in this attribute.
</p>
<p> The <code>.so</code> files produced by <code>cc_library</code>
rules are not linked against the libraries that they depend
on.  If you're trying to create a shared library for use
outside of the main repository, e.g. for manual use
with <code>dlopen()</code> or <code>LD_PRELOAD</code>,
it may be better to use a <code>cc_binary</code> rule
with the <code>linkshared=True</code> attribute.
See <a href="${link cc_binary.linkshared}"><code>cc_binary.linkshared</code></a>.
</p>
"""),
        # buildifier: disable=attr-license
        "licenses": attr.license() if hasattr(attr, "license") else attr.string_list(),
        "_stl": semantics.get_stl(),
        "_def_parser": semantics.get_def_parser(),
        "_use_auto_exec_groups": attr.bool(default = True),
        "_impl_delegate": attr.label(
            default = Label("//cc/private/rules_impl/wrappers:cc_library_impl_wrapper"),
            cfg = "exec",
        ),
    } | semantics.get_implementation_deps_allowed_attr() | semantics.get_nocopts_attr(),  # buildifier: disable=attr-licenses
    toolchains = use_cc_toolchain() + semantics.get_runtimes_toolchain(),
    fragments = ["cpp"] + semantics.additional_fragments(),
    provides = [CcInfo],
    exec_groups = {
        "cpp_link": exec_group(toolchains = use_cc_toolchain()),
    },
)
