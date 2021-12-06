#include "clang_format_utils.h"

#include <stdio.h>
#if defined(_WIN32) || defined(WIN32)
#include <direct.h>
#else
#include <unistd.h>
#endif

#include <cstdlib>
#include <fstream>
#include <iostream>

#if defined(_WIN32) || defined(WIN32)
#define IS_WINDOWS true
#define getcwd _getcwd
#define chdir _chdir
#else
#define IS_WINDOWS false
#endif

namespace clang_format_utils {

std::string get_working_path() {
  char temp[1024];
  return (getcwd(temp, sizeof(temp)) ? std::string(temp) : std::string(""));
}

int set_current_dir(const std::string& path) { return chdir(path.c_str()); }

int copy_file(const std::string& src, const std::string& dest) {
  if (IS_WINDOWS) {
    // Normalize paths on windows
    std::string win_src = src;
    size_t src_pos;
    while ((src_pos = win_src.find('/')) != std::string::npos) {
      win_src.replace(src_pos, 1, "\\");
    }
    std::string win_dest = dest;
    size_t dest_pos;
    while ((dest_pos = win_dest.find('/')) != std::string::npos) {
      win_dest.replace(dest_pos, 1, "\\");
    }

    // Create parent directory
    size_t sep_pos = win_dest.rfind("\\");
    if (sep_pos != std::string::npos) {
      std::string parent_dir = win_dest.substr(0, sep_pos);

      std::string mkdir_command = std::string("mkdir " + parent_dir);
      int exit_code = system(mkdir_command.c_str());
      if (exit_code) {
        return exit_code;
      }
    }
  } else {
    // Create parent directory
    size_t sep_pos = dest.rfind("/");
    if (sep_pos != std::string::npos) {
      std::string parent_dir = dest.substr(0, sep_pos);

      std::string mkdir_command = std::string("mkdir -p " + parent_dir);
      int exit_code = system(mkdir_command.c_str());
      if (exit_code) {
        return exit_code;
      }
    }
  }

  // Write the bytes of the source file to the dest file.
  std::ifstream src_stream(src, std::ios::binary);
  std::ofstream dst_stream(dest, std::ios::binary);
  dst_stream << src_stream.rdbuf();

  return 0;
}

}  // namespace clang_format_utils
