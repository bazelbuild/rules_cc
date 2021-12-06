#if defined(_WIN32) || defined(WIN32)
#include <stdio.h>
#endif

#include <fstream>
#include <iostream>
#include <string>
#include <vector>

#include "clang_format_utils.h"
#include "tools/cpp/runfiles/runfiles.h"

#if defined(_WIN32) || defined(WIN32)
#define FILE_SEP "\\"
#define popen _popen
#define pclose _pclose
#else
#define FILE_SEP "/"
#endif

using bazel::tools::cpp::runfiles::Runfiles;
using namespace clang_format_utils;

/**
 * @brief Parsable arguments for the clang-format runner program.
 *
 */
struct Args {
  // --config
  std::string config_path;

  // --clang_format
  std::string clang_format_path;

  // --types
  std::string types;

  // --extensions_manifest
  std::string extensions_manifest_path;

  // Trailing args after `--`. Defaults to `//...:all`
  std::string scope;

  // Environment variable BAZEL_REAL. Defaults to `bazel`.
  std::string bazel_path;

  // Environment variable BUILD_WORKSPACE_DIRECTORY.
  std::string build_workspace_directory;
};

/**
 * @brief Parse command line arguments.
 *
 * @param argc
 *  The number of command line arguments
 * @param argv
 *  A pointer to the list of command line arguments
 * @param out_args
 *  A reference variable in which to parse arguments into.
 * @return int
 *  The exit code for parsing command line arguments.
 */
int parse_args(int argc, char **argv, Args &out_args) {
  for (int i = 1; i < argc; ++i) {
    std::string arg = argv[i];
    if (++i == argc) {
      if (arg == "--") {
        out_args.scope = "//...:all";
        break;
      }

      std::cerr << "argument parser error: argument \"" << arg
                << "\" missing parameter.\n";
      return -1;
    } else if (arg == "--clang_format") {
      out_args.clang_format_path = argv[i];
    } else if (arg == "--config") {
      out_args.config_path = argv[i];
    } else if (arg == "--extensions_manifest") {
      out_args.extensions_manifest_path = argv[i];
    } else if (arg == "--types") {
      out_args.types = argv[i];
    } else if (arg == "--") {
      out_args.scope = argv[i];
      for (++i; i < argc; ++i) {
        out_args.scope = out_args.scope + " " + argv[i];
      }
      break;
    } else {
      std::cerr << "argument parser error: unknow argument \"" << arg << "\"."
                << '\n';
      return -1;
    }
  }

  if (out_args.config_path.empty()) {
    std::cerr
        << "argument parser error: missing required argument `--config`\n";
    return -1;
  }

  if (out_args.scope.empty()) {
    std::cerr << "argument parser error: missing required argument `--scope`\n";
    return -1;
  }

  const char *bazel_real_var = std::getenv("BAZEL_REAL");
  std::string bazel_real(bazel_real_var ? bazel_real_var : "");
  if (!bazel_real.empty()) {
    out_args.bazel_path = bazel_real;
  } else {
    out_args.bazel_path = "bazel";
  }

  // Query the environment for the path on the filesystem to the Bazel
  // workspace directory.
  const char *build_workspace_directory_var =
      std::getenv("BUILD_WORKSPACE_DIRECTORY");
  std::string build_workspace_directory(
      build_workspace_directory_var ? build_workspace_directory_var : "");
  if (build_workspace_directory.empty()) {
    std::cerr << "argument parser error: BUILD_WORKSPACE_DIRECTORY is not set. "
                 "Is the process running under Bazel? \"\n";
    return -1;
  }
  out_args.build_workspace_directory = build_workspace_directory;

  // Load the Runfiles library
  std::string error = {};
  std::unique_ptr<Runfiles> runfiles(Runfiles::Create(argv[0], &error));
  if (runfiles == nullptr) {
    std::cerr << "argument parser error: \"" << error << "\n";
    return -1;
  }

  std::string workspace_name = WORKSPACE_NAME;

  // Generate absolute paths to all important runfiles.
  out_args.extensions_manifest_path = runfiles->Rlocation(
      workspace_name + "/" + out_args.extensions_manifest_path);
  out_args.config_path =
      runfiles->Rlocation(workspace_name + "/" + out_args.config_path);
  out_args.clang_format_path =
      runfiles->Rlocation(workspace_name + "/" + out_args.clang_format_path);

  return 0;
}

/**
 * @brief Spawn a process while waiting for it's completion and capturing
 * stdout.
 *
 * @param cmd
 *  The command to run.
 * @param out_stream
 *  A reference variable in which to write the stdout stream.
 * @return int
 *  The processes exit code.
 */
int exec(const char *cmd, std::string &out_stream) {
  char buffer[1024];
  FILE *pipe = popen(cmd, "r");
  if (!pipe) throw std::runtime_error("popen() failed!");
  try {
    while (fgets(buffer, sizeof buffer, pipe) != NULL) {
      out_stream += buffer;
    }
  } catch (...) {
    pclose(pipe);
    throw;
  }
  return pclose(pipe);
}

/**
 * @brief Run a command within a requested directory while capturing stdout.
 *
 * @param exec_path
 *  The binary to execute.
 * @param arguments
 *  Arugments for the binary at `exec_path`.
 * @param cwd
 *  The working directory for the new process.
 * @param out_stream
 *  A reference variable in which to write the stdout stream.
 * @return int
 *  The exit code of the subprocess.
 */
int execute(const std::string &exec_path,
            const std::vector<std::string> &arguments, const std::string &cwd,
            std::string &out_stream) {
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

  int exit_code = exec(command.c_str(), out_stream);

  chdir_exit_code = set_current_dir(pwd);
  if (chdir_exit_code) {
    return chdir_exit_code;
  }

  return exit_code;
}

/**
 * @brief Replace text within a string.
 *
 * @param out_str
 *  The string to replace text in.
 * @param from
 *  The substring to remove.
 * @param to
 *  The string to put in place of `from`.
 */
void str_replace(std::string &out_str, const std::string &from,
                 const std::string &to) {
  for (size_t pos = 0;; pos += to.length()) {
    // Locate the substring to replace
    pos = out_str.find(from, pos);
    if (pos == std::string::npos) break;
    // Replace by erasing and inserting
    out_str.erase(pos, from.length());
    out_str.insert(pos, to);
  }
}

/**
 * @brief Split a string into an array, separated by a give delimiter.
 *
 * @param s
 *  The string to split.
 * @param delimiter
 *  The text to split the string by.
 * @return std::vector<std::string>
 *  The list of all substrings separated by the delimiter.
 */
std::vector<std::string> str_split(const std::string &s,
                                   const std::string delimiter) {
  size_t pos_start = 0, pos_end, delim_len = delimiter.length();
  std::string token;
  std::vector<std::string> res;

  while ((pos_end = s.find(delimiter, pos_start)) != std::string::npos) {
    token = s.substr(pos_start, pos_end - pos_start);
    pos_start = pos_end + delim_len;
    res.push_back(token);
  }

  return res;
}

/**
 * @brief Query for all formattable source targets within the current Bazel
 * workspace.
 *
 * @param bazel_path
 *  The path to a Bazel executable.
 * @param extensions_manifest_path
 *  The path to a `build_setting_file` target containing formattable extensions.
 * @param scope
 *  Package or target labels filtering what should be formatted.
 * @param types
 *  A regex pattern of what rules to gather source dependencies from for
 * formatting.
 * @param workspace_dir
 *  The directory of the workspace in which to run the query.
 * @param out_sources
 *  A reference variable where source files will be collected.
 * @return int
 *  The exit code of the query
 */
int query_sources(const std::string &bazel_path,
                  const std::string &extensions_manifest_path,
                  const std::string &scope, const std::string &types,
                  const std::string &workspace_dir,
                  std::vector<std::string> &out_sources) {
  std::string query_template =
      "\"filter('^//.*\\.({extensions})$', kind('source file', "
      "deps(kind('{types}', set({scope}) except attr(tags, '(^\\[|, "
      ")(noformat|no-format|no-clang-format)(, |\\]$)', set({scope}))), 1)))\"";

  // Read in the list of formattable extensions and covert it to a regex string
  std::ifstream ifs(extensions_manifest_path);
  std::string extensions((std::istreambuf_iterator<char>(ifs)),
                         (std::istreambuf_iterator<char>()));
  str_replace(extensions, "\n", "|");
  str_replace(extensions, "+", "\\+");

  // Resolve all the template arguments in the query string
  std::string query_arg = query_template;
  str_replace(query_arg, "{extensions}", extensions);
  str_replace(query_arg, "{scope}", scope);
  str_replace(query_arg, "{types}", types);

  std::string stream;
  std::vector<std::string> query_args = {
      "query",
      query_arg,
      "--keep_going",
      "--noimplicit_deps",
  };
  int exit_code = execute(bazel_path, query_args, workspace_dir, stream);

  if (exit_code) {
    return exit_code;
  }

  out_sources = str_split(stream, "\n");

  return 0;
}

/**
 * @brief The main entry point for the clang-fromat runner tool.
 *
 * @param argc
 *  The number of command line arguments.
 * @param argv
 *  A pointer to the list of command line arguments.
 * @return int
 *  The exit code for the program.
 */
int main(int argc, char **argv) {
  // Parse command line arguments
  Args args = {};
  int arg_parse_exit_code = parse_args(argc, argv, args);
  if (arg_parse_exit_code) {
    return arg_parse_exit_code;
  }

  // Gather formattable sources from targets
  std::vector<std::string> targets{};
  int query_exit_code =
      query_sources(args.bazel_path, args.extensions_manifest_path, args.scope,
                    args.types, args.build_workspace_directory, targets);
  if (query_exit_code) {
    return query_exit_code;
  }

  // Create a directory with a config file in which to run clang-format
  std::string format_dir =
      get_working_path() + FILE_SEP + ".clang_format_workdir";
  int config_copy_exit_code =
      copy_file(args.config_path, format_dir + FILE_SEP + ".clang-format");
  if (config_copy_exit_code) {
    return config_copy_exit_code;
  }

  // Recreate the directory tree in a new directory to ensure no onther
  // clang-format configs are used when formatting
  for (const std::string &target : targets) {
    std::string src = target;
    str_replace(src, "//", "");
    str_replace(src, ":", "/");

    std::string real_src = args.build_workspace_directory + FILE_SEP + src;
    std::string dest_src = format_dir + FILE_SEP + src;

    int src_copy_exit_code = copy_file(real_src, dest_src);
    if (src_copy_exit_code) {
      return src_copy_exit_code;
    }

    // Format all available sources
    std::string stream;
    std::vector<std::string> clang_format_args = {
        "-style=file",
        "-i",
        dest_src,
    };
    int exit_code =
        execute(args.clang_format_path, clang_format_args, format_dir, stream);
    if (exit_code) {
      return exit_code;
    }

    // Copy all sources back to the repo
    src_copy_exit_code = copy_file(dest_src, real_src);
    if (src_copy_exit_code) {
      return src_copy_exit_code;
    }
  }

  return 0;
}
