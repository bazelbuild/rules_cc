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
"""Expected legacy feature textprotos."""

visibility("private")

GOLDENS = {
    "macos/archiver_flags": """enabled: false
flag_sets {
  actions: "c++-link-static-library"
  actions: "objc-fully-link"
  flag_groups {
    flags: "-D"
    flags: "-no_warning_for_no_symbols"
    flags: "-static"
  }
}
flag_sets {
  actions: "c++-link-static-library"
  flag_groups {
    expand_if_available: "output_execpath"
    flags: "-o"
    flags: "%{output_execpath}"
  }
}
flag_sets {
  actions: "objc-fully-link"
  flag_groups {
    expand_if_available: "fully_linked_archive_path"
    flags: "-o"
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
""",
    "macos/force_pic_flags": """enabled: false
flag_sets {
  actions: "c++-link-executable"
  actions: "lto-index-for-executable"
  actions: "objc-executable"
  flag_groups {
    expand_if_available: "force_pic"
    flags: "-Wl,-pie"
  }
}
name: "force_pic_flags_test"
""",
    "macos/libraries_to_link": """enabled: false
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
""",
    "macos/runtime_library_search_directories": """enabled: false
flag_sets {
  actions: "c++-link-dynamic-library"
  actions: "c++-link-executable"
  actions: "c++-link-nodeps-dynamic-library"
  actions: "lto-index-for-dynamic-library"
  actions: "lto-index-for-executable"
  actions: "lto-index-for-nodeps-dynamic-library"
  actions: "objc-executable"
  flag_groups {
    expand_if_available: "runtime_library_search_directories"
    flag_groups {
      flag_groups {
        expand_if_true: "is_cc_test"
        flags: "-Xlinker"
        flags: "-rpath"
        flags: "-Xlinker"
        flags: "$EXEC_ORIGIN/%{runtime_library_search_directories}"
      }
      flag_groups {
        expand_if_false: "is_cc_test"
        flags: "-Xlinker"
        flags: "-rpath"
        flags: "-Xlinker"
        flags: "@loader_path/%{runtime_library_search_directories}"
      }
      iterate_over: "runtime_library_search_directories"
    }
  }
  with_features {
    features: "static_link_cpp_runtimes"
  }
}
flag_sets {
  actions: "c++-link-dynamic-library"
  actions: "c++-link-executable"
  actions: "c++-link-nodeps-dynamic-library"
  actions: "lto-index-for-dynamic-library"
  actions: "lto-index-for-executable"
  actions: "lto-index-for-nodeps-dynamic-library"
  actions: "objc-executable"
  flag_groups {
    expand_if_available: "runtime_library_search_directories"
    flag_groups {
      flags: "-Xlinker"
      flags: "-rpath"
      flags: "-Xlinker"
      flags: "@loader_path/%{runtime_library_search_directories}"
      iterate_over: "runtime_library_search_directories"
    }
  }
  with_features {
    not_features: "static_link_cpp_runtimes"
  }
}
name: "runtime_library_search_directories_test"
""",
    "unix/archiver_flags": """enabled: false
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
""",
    "unix/force_pic_flags": """enabled: false
flag_sets {
  actions: "c++-link-executable"
  actions: "lto-index-for-executable"
  actions: "objc-executable"
  flag_groups {
    expand_if_available: "force_pic"
    flags: "-pie"
  }
}
name: "force_pic_flags_test"
""",
    "unix/libraries_to_link": """enabled: false
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
            expand_if_true: "libraries_to_link.is_whole_archive"
            flag_groups {
              expand_if_equal {
                name: "libraries_to_link.type"
                value: "static_library"
              }
              flags: "-Wl,-whole-archive"
            }
          }
          flag_groups {
            expand_if_equal {
              name: "libraries_to_link.type"
              value: "object_file_group"
            }
            flags: "%{libraries_to_link.object_files}"
            iterate_over: "libraries_to_link.object_files"
          }
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
              value: "interface_library"
            }
            flags: "%{libraries_to_link.name}"
          }
          flag_groups {
            expand_if_equal {
              name: "libraries_to_link.type"
              value: "static_library"
            }
            flags: "%{libraries_to_link.name}"
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
            flags: "-l:%{libraries_to_link.name}"
          }
          flag_groups {
            expand_if_true: "libraries_to_link.is_whole_archive"
            flag_groups {
              expand_if_equal {
                name: "libraries_to_link.type"
                value: "static_library"
              }
              flags: "-Wl,-no-whole-archive"
            }
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
""",
    "unix/linker_param_file": """enabled: false
flag_sets {
  actions: "c++-link-dynamic-library"
  actions: "c++-link-executable"
  actions: "c++-link-nodeps-dynamic-library"
  actions: "c++-link-static-library"
  actions: "lto-index-for-dynamic-library"
  actions: "lto-index-for-executable"
  actions: "lto-index-for-nodeps-dynamic-library"
  actions: "objc-executable"
  actions: "objc-fully-link"
  flag_groups {
    expand_if_available: "linker_param_file"
    flags: "@%{linker_param_file}"
  }
}
name: "linker_param_file_test"
""",
    "unix/runtime_library_search_directories": """enabled: false
flag_sets {
  actions: "c++-link-dynamic-library"
  actions: "c++-link-executable"
  actions: "c++-link-nodeps-dynamic-library"
  actions: "lto-index-for-dynamic-library"
  actions: "lto-index-for-executable"
  actions: "lto-index-for-nodeps-dynamic-library"
  actions: "objc-executable"
  flag_groups {
    expand_if_available: "runtime_library_search_directories"
    flag_groups {
      flag_groups {
        expand_if_true: "is_cc_test"
        flags: "-Xlinker"
        flags: "-rpath"
        flags: "-Xlinker"
        flags: "$EXEC_ORIGIN/%{runtime_library_search_directories}"
      }
      flag_groups {
        expand_if_false: "is_cc_test"
        flags: "-Xlinker"
        flags: "-rpath"
        flags: "-Xlinker"
        flags: "$ORIGIN/%{runtime_library_search_directories}"
      }
      iterate_over: "runtime_library_search_directories"
    }
  }
  with_features {
    features: "static_link_cpp_runtimes"
  }
}
flag_sets {
  actions: "c++-link-dynamic-library"
  actions: "c++-link-executable"
  actions: "c++-link-nodeps-dynamic-library"
  actions: "lto-index-for-dynamic-library"
  actions: "lto-index-for-executable"
  actions: "lto-index-for-nodeps-dynamic-library"
  actions: "objc-executable"
  flag_groups {
    expand_if_available: "runtime_library_search_directories"
    flag_groups {
      flags: "-Xlinker"
      flags: "-rpath"
      flags: "-Xlinker"
      flags: "$ORIGIN/%{runtime_library_search_directories}"
      iterate_over: "runtime_library_search_directories"
    }
  }
  with_features {
    not_features: "static_link_cpp_runtimes"
  }
}
name: "runtime_library_search_directories_test"
""",
    "unix/shared_flag": """enabled: false
flag_sets {
  actions: "c++-link-dynamic-library"
  actions: "c++-link-nodeps-dynamic-library"
  actions: "lto-index-for-dynamic-library"
  actions: "lto-index-for-nodeps-dynamic-library"
  flag_groups {
    flags: "-shared"
  }
}
name: "shared_flag_test"
""",
}
