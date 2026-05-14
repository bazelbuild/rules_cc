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
"""Expected libraries_to_link legacy feature textproto on macOS."""

visibility("private")

GOLDEN = """enabled: false
flag_sets {
  actions: "c++-link-dynamic-library"
  actions: "c++-link-executable"
  actions: "c++-link-nodeps-dynamic-library"
  actions: "lto-index-for-dynamic-library"
  actions: "lto-index-for-executable"
  actions: "lto-index-for-nodeps-dynamic-library"
  actions: "objc-executable"
  flag_groups {
    flag_groups {
      expand_if_available: "thinlto_param_file"
      flags: "-Wl,@%{thinlto_param_file}"
    }
    flag_groups {
      expand_if_available: "libraries_to_link"
      flag_groups {
        flag_groups {
          expand_if_equal {
            name: "libraries_to_link.type"
            value: "object_file_group"
          }
          flag_groups {
            expand_if_false: "libraries_to_link.is_whole_archive"
            flags: "-Wl,--start-lib"
          }
        }
        flag_groups {
          flag_groups {
            expand_if_equal {
              name: "libraries_to_link.type"
              value: "object_file_group"
            }
            flag_groups {
              flag_groups {
                expand_if_true: "libraries_to_link.is_whole_archive"
                flags: "-Wl,-force_load,%{libraries_to_link.object_files}"
              }
              flag_groups {
                expand_if_false: "libraries_to_link.is_whole_archive"
                flags: "%{libraries_to_link.object_files}"
              }
            }
            iterate_over: "libraries_to_link.object_files"
          }
          flag_groups {
            expand_if_equal {
              name: "libraries_to_link.type"
              value: "object_file"
            }
            flag_groups {
              flag_groups {
                expand_if_true: "libraries_to_link.is_whole_archive"
                flags: "-Wl,-force_load,%{libraries_to_link.name}"
              }
              flag_groups {
                expand_if_false: "libraries_to_link.is_whole_archive"
                flags: "%{libraries_to_link.name}"
              }
            }
          }
          flag_groups {
            expand_if_equal {
              name: "libraries_to_link.type"
              value: "interface_library"
            }
            flag_groups {
              flag_groups {
                expand_if_true: "libraries_to_link.is_whole_archive"
                flags: "-Wl,-force_load,%{libraries_to_link.name}"
              }
              flag_groups {
                expand_if_false: "libraries_to_link.is_whole_archive"
                flags: "%{libraries_to_link.name}"
              }
            }
          }
          flag_groups {
            expand_if_equal {
              name: "libraries_to_link.type"
              value: "static_library"
            }
            flag_groups {
              flag_groups {
                expand_if_true: "libraries_to_link.is_whole_archive"
                flags: "-Wl,-force_load,%{libraries_to_link.name}"
              }
              flag_groups {
                expand_if_false: "libraries_to_link.is_whole_archive"
                flags: "%{libraries_to_link.name}"
              }
            }
          }
          flag_groups {
            expand_if_equal {
              name: "libraries_to_link.type"
              value: "dynamic_library"
            }
            flags: "-l%{libraries_to_link.name}"
          }
          flag_groups {
            expand_if_equal {
              name: "libraries_to_link.type"
              value: "versioned_dynamic_library"
            }
            flags: "%{libraries_to_link.path}"
          }
        }
        flag_groups {
          expand_if_equal {
            name: "libraries_to_link.type"
            value: "object_file_group"
          }
          flag_groups {
            expand_if_false: "libraries_to_link.is_whole_archive"
            flags: "-Wl,--end-lib"
          }
        }
        iterate_over: "libraries_to_link"
      }
    }
  }
}
name: "libraries_to_link_test"
"""
