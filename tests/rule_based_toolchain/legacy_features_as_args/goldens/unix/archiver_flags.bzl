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
"""Expected archiver_flags legacy feature textproto on unix."""

visibility("private")

GOLDEN = """enabled: false
flag_sets {
  actions: "c++-link-static-library"
  actions: "objc-fully-link"
  flag_groups {
    flags: "rcsD"
  }
}
flag_sets {
  actions: "c++-link-static-library"
  flag_groups {
    expand_if_available: "output_execpath"
    flags: "%{output_execpath}"
  }
}
flag_sets {
  actions: "objc-fully-link"
  flag_groups {
    expand_if_available: "fully_linked_archive_path"
    flags: "%{fully_linked_archive_path}"
  }
}
flag_sets {
  actions: "c++-link-static-library"
  flag_groups {
    expand_if_available: "libraries_to_link"
    flag_groups {
      flag_groups {
        expand_if_equal {
          name: "libraries_to_link.type"
          value: "object_file"
        }
        flags: "%{libraries_to_link.name}"
      }
      flag_groups {
        expand_if_equal {
          name: "libraries_to_link.type"
          value: "object_file_group"
        }
        flags: "%{libraries_to_link.object_files}"
        iterate_over: "libraries_to_link.object_files"
      }
      iterate_over: "libraries_to_link"
    }
  }
}
flag_sets {
  actions: "objc-fully-link"
  flag_groups {
    expand_if_available: "objc_library_exec_paths"
    flags: "%{objc_library_exec_paths}"
    iterate_over: "objc_library_exec_paths"
  }
}
flag_sets {
  actions: "objc-fully-link"
  flag_groups {
    expand_if_available: "cc_library_exec_paths"
    flags: "%{cc_library_exec_paths}"
    iterate_over: "cc_library_exec_paths"
  }
}
flag_sets {
  actions: "objc-fully-link"
  flag_groups {
    expand_if_available: "imported_library_exec_paths"
    flags: "%{imported_library_exec_paths}"
    iterate_over: "imported_library_exec_paths"
  }
}
name: "archiver_flags_test"
"""
