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

"""cc_binary Starlark declaration replacing native"""

load("//cc:cc_postmark_initializers.bzl", "postmark_initializer")
load("//cc:use_cc_toolchain.bzl", "use_cc_toolchain")
load("//cc/common:cc_info.bzl", "CcInfo")
load("//cc/common:semantics.bzl", "semantics")
load(":attrs.bzl", "cc_binary_attrs")
load(":cc_shared_library.bzl", "dynamic_deps_initializer")
load(":function_providing_rule.bzl", "proxy")

def _cc_binary_initializer(**kwargs):
    kwargs = postmark_initializer(**kwargs)
    return dynamic_deps_initializer(**kwargs)

cc_binary = rule(
    implementation = proxy,
    initializer = _cc_binary_initializer,
    doc = """
<p>It produces an executable binary.</p>

<br/>The <code>name</code> of the target should be the same as the name of the
source file that is the main entry point of the application (minus the extension).
For example, if your entry point is in <code>main.cc</code>, then your name should
be <code>main</code>.

<h4>Implicit output targets</h4>
<ul>
<li><code><var>name</var>.stripped</code> (only built if explicitly requested): A stripped
  version of the binary. <code>strip -g</code> is run on the binary to remove debug
  symbols.  Additional strip options can be provided on the command line using
  <code>--stripopt=-foo</code>.</li>
<li><code><var>name</var>.dwp</code> (only built if explicitly requested): If
  <a href="https://gcc.gnu.org/wiki/DebugFission">Fission</a> is enabled: a debug
  information package file suitable for debugging remotely deployed binaries. Else: an
  empty file.</li>
</ul>
""" + semantics.cc_binary_extra_docs,
    attrs = cc_binary_attrs | {"_impl_delegate": attr.label(
        default = Label("//cc/private/rules_impl/wrappers:cc_binary_impl_wrapper"),
        cfg = "exec",
    )},
    outputs = {
        "dwp_file": "%{name}.dwp",
        "stripped_binary": "%{name}.stripped",
    },
    fragments = ["cpp"] + semantics.additional_fragments(),
    exec_groups = {
        "cpp_link": exec_group(toolchains = use_cc_toolchain()),
    } | semantics.extra_exec_groups,
    toolchains = use_cc_toolchain() +
                 semantics.get_runtimes_toolchain(),
    provides = [CcInfo],
    executable = True,
)
