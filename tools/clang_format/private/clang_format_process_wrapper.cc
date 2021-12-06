#include <stdio.h>

#include <cstdlib>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

#include "clang_format_utils.h"

#if defined(_WIN32) || defined(WIN32)
#define FILE_SEP "\\"
#else
#define FILE_SEP "/"
#endif

using namespace clang_format_utils;

/**
 * @brief Run a command within a requested directory.
 *
 * @param exec_path
 *  The binary to execute.
 * @param arguments
 *  Arugments for the binary at `exec_path`.
 * @param cwd
 *  The working directory for the new process.
 * @return int
 *  The exit code of the subprocess.
 */
int execute(const std::string &exec_path,
            const std::vector<std::string> &arguments, const std::string &cwd) {
  std::string pwd = get_working_path();
  std::string command = exec_path;

  for (const std::string &arg : arguments) {
    command += " " + arg;
  }

  int chdir_exit_code = 0;

  chdir_exit_code = set_current_dir(cwd);
  if (chdir_exit_code) {
    return chdir_exit_code;
  }

  int exit_code = system(command.c_str());

  chdir_exit_code = set_current_dir(pwd);
  if (chdir_exit_code) {
    return chdir_exit_code;
  }

  return exit_code;
}

/**
 * @brief Run clang-format on a list of source files
 *
 * @param clang_format_file
 *  The path to a clang-format binary
 * @param clang_format_arguments
 *  Arguments for clang-format
 * @param config_file
 *  The clang-format config file (`.clang-format` file).
 * @param sources
 *  A list of source files to format.
 * @param diff_tool_file
 *  The path to a diff tool with which to inspect formatting changes
 * @return int
 *  The exit code of the clang-format process.
 */
int run_clang_format(const std::string &clang_format_file,
                     const std::vector<std::string> &clang_format_arguments,
                     const std::string &config_file,
                     const std::vector<std::string> &sources,
                     const std::string &diff_tool_file) {
  std::string working_dir = "__clang_format__";

  // Install the config file if one was provided
  if (!config_file.empty()) {
    std::string dest = working_dir + "/.clang-format";
    int exit_code = copy_file(config_file, dest);
    if (exit_code) {
      return exit_code;
    }
  }

  // If a diff tool was given, a series of additional commands
  // will be run to ensure there are no differences while also
  // allowing nicely formatted errors to propogate to users.
  bool use_diff_tool = !diff_tool_file.empty();
  std::vector<std::string> diff_commands = {};
  if (use_diff_tool) {
    diff_commands.reserve(sources.size());
  }

  // Create copies of of the source files to format
  for (const std::string &src : sources) {
    std::string dest = working_dir + "/" + src;
    int exit_code = copy_file(src, dest);
    if (exit_code) {
      return exit_code;
    }

    if (use_diff_tool) {
      diff_commands.push_back(diff_tool_file + " " + src + " " + dest);
    }
  }

  std::string pwd = get_working_path();
  std::string clang_format_path = pwd + FILE_SEP + clang_format_file;

  // Run clang-format
  int format_exit_code =
      execute(clang_format_path, clang_format_arguments, working_dir);
  if (format_exit_code || !use_diff_tool) {
    return format_exit_code;
  }

  // Show diffs
  int diff_exit_code = 0;
  for (std::string &command : diff_commands) {
    int exit_code = system(command.c_str());
    diff_exit_code = diff_exit_code ? diff_exit_code : exit_code;
  }
  if (diff_exit_code) {
    return diff_exit_code;
  }

  return 0;
}

/**
 * @brief The main entry point for the clang-fromat rule's process wrapper.
 *
 * @param argc
 *  The number of command line arguments.
 * @param argv
 *  A pointer to the list of command line arguments.
 * @return int
 *  The exit code for the program.
 */
int main(int argc, char **argv) {
  std::string exec_path, diff_tool_file, config_file, touch_file = {};
  std::vector<std::string> arguments, diff_commands, sources = {};

  for (int i = 1; i < argc; ++i) {
    std::string arg = argv[i];
    if (++i == argc) {
      std::cerr << "process wrapper error: argument \"" << arg
                << "\" missing parameter.\n";
      return -1;
    } else if (arg == "--touch-file") {
      if (!touch_file.empty()) {
        std::cerr << "process wrapper error: \"--touch-file\" can only "
                     "appear "
                     "once.\n";
        return -1;
      }
      touch_file = argv[i];
    } else if (arg == "--diff-tool-file") {
      if (!diff_tool_file.empty()) {
        std::cerr << "process wrapper error: \"--diff-tool-file\" can "
                     "only appear "
                     "once.\n";
        return -1;
      }
      diff_tool_file = argv[i];
    } else if (arg == "--config-file") {
      if (!config_file.empty()) {
        std::cerr << "process wrapper error: \"--config-file\" can "
                     "only appear "
                     "once.\n";
        return -1;
      }
      config_file = argv[i];
    } else if (arg == "--source-file") {
      sources.push_back(argv[i]);
    } else if (arg == "--") {
      exec_path = argv[i];
      for (++i; i < argc; ++i) {
        arguments.push_back(argv[i]);
      }
      break;
    } else {
      std::cerr << "process wrapper error: unknown argument \"" << arg << "\"."
                << '\n';
      return -1;
    }
  }

  arguments.reserve(sources.size());
  for (const std::string &src : sources) {
    arguments.push_back(src);
  }

  int exit_code = run_clang_format(exec_path, arguments, config_file, sources,
                                   diff_tool_file);
  if (exit_code) {
    return exit_code;
  }

  if (!touch_file.empty()) {
    std::ofstream file(touch_file);
    if (file.fail()) {
      std::cerr << "process wrapper error: failed to create touch file: \""
                << touch_file << "\"\n";
      return -1;
    }
    file.close();
  }

  return 0;
}
