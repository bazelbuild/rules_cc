# Copyright 2026 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Expected thin_lto legacy feature textproto on macOS."""

visibility("private")

GOLDEN = """enabled: false
flag_sets {
  actions: "c++-compile"
  actions: "c++-link-dynamic-library"
  actions: "c++-link-executable"
  actions: "c++-link-nodeps-dynamic-library"
  actions: "c-compile"
  actions: "lto-index-for-dynamic-library"
  actions: "lto-index-for-executable"
  actions: "lto-index-for-nodeps-dynamic-library"
  actions: "objc-executable"
  flag_groups {
    flags: "-flto=thin"
  }
}
flag_sets {
  actions: "assemble"
  actions: "c++-compile"
  actions: "c++-header-parsing"
  actions: "c++-module-codegen"
  actions: "c++-module-compile"
  actions: "c-compile"
  actions: "clif-match"
  actions: "linkstamp-compile"
  actions: "lto-backend"
  actions: "objc++-compile"
  actions: "objc-compile"
  actions: "preprocess-assemble"
  flag_groups {
    expand_if_available: "lto_indexing_bitcode_file"
    flags: "-Xclang"
    flags: "-fthin-link-bitcode=%{lto_indexing_bitcode_file}"
  }
}
flag_sets {
  actions: "lto-index-for-dynamic-library"
  actions: "lto-index-for-executable"
  actions: "lto-index-for-nodeps-dynamic-library"
  flag_groups {
    expand_if_available: "thinlto_merged_object_file"
    flags: "-Wl,--lto-obj-path=%{thinlto_merged_object_file}"
  }
}
flag_sets {
  actions: "lto-backend"
  flag_groups {
    expand_if_available: "thinlto_index"
    flags: "-c"
    flags: "-fthinlto-index=%{thinlto_index}"
  }
}
flag_sets {
  actions: "lto-backend"
  flag_groups {
    expand_if_available: "thinlto_output_object_file"
    flags: "-o"
    flags: "%{thinlto_output_object_file}"
  }
}
flag_sets {
  actions: "lto-backend"
  flag_groups {
    expand_if_available: "thinlto_input_bitcode_file"
    flags: "-x"
    flags: "ir"
    flags: "%{thinlto_input_bitcode_file}"
  }
}
flag_sets {
  actions: "lto-index-for-dynamic-library"
  actions: "lto-index-for-executable"
  actions: "lto-index-for-nodeps-dynamic-library"
  flag_groups {
    expand_if_available: "thinlto_indexing_param_file"
    flags: "-Wl,--thinlto-index-only=%{thinlto_indexing_param_file}"
  }
}
flag_sets {
  actions: "lto-index-for-dynamic-library"
  actions: "lto-index-for-executable"
  actions: "lto-index-for-nodeps-dynamic-library"
  flag_groups {
    flags: "-Wl,--thinlto-emit-imports-files"
  }
}
flag_sets {
  actions: "lto-index-for-dynamic-library"
  actions: "lto-index-for-executable"
  actions: "lto-index-for-nodeps-dynamic-library"
  flag_groups {
    expand_if_available: "thinlto_prefix_replace"
    flags: "-Wl,--thinlto-prefix-replace=%{thinlto_prefix_replace}"
  }
}
flag_sets {
  actions: "lto-index-for-dynamic-library"
  actions: "lto-index-for-executable"
  actions: "lto-index-for-nodeps-dynamic-library"
  flag_groups {
    expand_if_available: "thinlto_object_suffix_replace"
    flags: "-Wl,--thinlto-object-suffix-replace=%{thinlto_object_suffix_replace}"
  }
}
name: "thin_lto"
"""
