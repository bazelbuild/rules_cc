// Copyright 2016 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/// @file coverage_utils.cc
/// @brief Implementation of the helpers declared in @c coverage_utils.h.

#include "cc/private/coverage/coverage_utils.h"

#include <algorithm>
#include <cctype>
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <optional>
#include <sstream>
#include <string>
#include <string_view>
#include <system_error>
#include <utility>
#include <vector>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#else
#include <fcntl.h>
#include <spawn.h>
#include <sys/wait.h>
#include <unistd.h>
extern char** environ;
#endif

namespace fs = std::filesystem;

namespace bazel_coverage {

namespace {

/// @brief When true, log every external command that is executed.
bool g_verbose = false;

/// @brief Return true when @p s ends with @p suffix.
bool EndsWith(std::string_view s, std::string_view suffix) {
  return s.size() >= suffix.size() &&
         s.compare(s.size() - suffix.size(), suffix.size(), suffix) == 0;
}

/// @brief Trim ASCII whitespace and carriage returns from both ends.
std::string TrimAscii(std::string s) {
  auto is_space = [](unsigned char c) {
    return c == ' ' || c == '\t' || c == '\r' || c == '\n';
  };
  size_t begin = 0;
  while (begin < s.size() && is_space(s[begin])) {
    ++begin;
  }
  size_t end = s.size();
  while (end > begin && is_space(s[end - 1])) {
    --end;
  }
  return s.substr(begin, end - begin);
}

/// @brief Split a string on ASCII whitespace, dropping empty tokens.
std::vector<std::string> SplitWhitespace(const std::string& s) {
  std::vector<std::string> out;
  std::istringstream iss(s);
  std::string tok;
  while (iss >> tok) {
    out.push_back(std::move(tok));
  }
  return out;
}

/// @brief Result of running an external process.
struct ProcessResult {
  /// @brief Exit code of the child, or @c -1 if it failed to spawn or was
  ///        terminated by a signal.
  int exit_code = -1;
  /// @brief Captured standard output when requested; empty otherwise.
  std::string stdout_text;
};

/// @brief Translate a @c ProcessResult exit code into a value suitable for the
///        parent process: @c -1 (spawn failure / signal) becomes @c 1.
int NormalizeExit(int exit_code) { return exit_code == -1 ? 1 : exit_code; }

#ifdef _WIN32

/// @brief Quote a single argument for the Windows command line.
///
/// Implements the algorithm documented for @c CommandLineToArgvW so that the
/// child process sees @p arg exactly as intended.
std::string QuoteWindowsArg(const std::string& arg) {
  if (!arg.empty() && arg.find_first_of(" \t\n\v\"") == std::string::npos) {
    return arg;
  }
  std::string out;
  out.push_back('"');
  for (size_t i = 0; i < arg.size();) {
    size_t backslashes = 0;
    while (i < arg.size() && arg[i] == '\\') {
      ++backslashes;
      ++i;
    }
    if (i == arg.size()) {
      out.append(backslashes * 2, '\\');
    } else if (arg[i] == '"') {
      out.append(backslashes * 2 + 1, '\\');
      out.push_back('"');
      ++i;
    } else {
      out.append(backslashes, '\\');
      out.push_back(arg[i]);
      ++i;
    }
  }
  out.push_back('"');
  return out;
}

/// @brief Convert a UTF-8 string to a UTF-16 wide string.
std::wstring Utf8ToWide(const std::string& s) {
  if (s.empty()) {
    return std::wstring();
  }
  int size = MultiByteToWideChar(CP_UTF8, 0, s.data(),
                                 static_cast<int>(s.size()), nullptr, 0);
  std::wstring result(static_cast<size_t>(size), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, s.data(), static_cast<int>(s.size()),
                      result.data(), size);
  return result;
}

/// @brief Run @p args as a child process on Windows.
ProcessResult RunProcess(const std::vector<std::string>& args,
                         bool capture_stdout) {
  ProcessResult result;
  if (args.empty()) {
    return result;
  }

  std::string cmdline;
  for (size_t i = 0; i < args.size(); ++i) {
    if (i > 0) {
      cmdline.push_back(' ');
    }
    cmdline.append(QuoteWindowsArg(args[i]));
  }
  if (g_verbose) {
    std::cerr << "+ " << cmdline << '\n';
  }

  HANDLE read_pipe = nullptr;
  HANDLE write_pipe = nullptr;
  SECURITY_ATTRIBUTES sa{sizeof(sa), nullptr, TRUE};
  if (capture_stdout) {
    if (!CreatePipe(&read_pipe, &write_pipe, &sa, 0)) {
      std::cerr << "CreatePipe failed: " << GetLastError() << '\n';
      return result;
    }
    SetHandleInformation(read_pipe, HANDLE_FLAG_INHERIT, 0);
  }

  STARTUPINFOW si{};
  si.cb = sizeof(si);
  si.dwFlags = STARTF_USESTDHANDLES;
  si.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
  si.hStdError = GetStdHandle(STD_ERROR_HANDLE);
  si.hStdOutput = capture_stdout ? write_pipe : GetStdHandle(STD_OUTPUT_HANDLE);

  PROCESS_INFORMATION pi{};
  std::wstring app = Utf8ToWide(args[0]);
  std::wstring wide_cmdline = Utf8ToWide(cmdline);
  BOOL ok = CreateProcessW(app.c_str(), wide_cmdline.data(), nullptr, nullptr,
                           TRUE, 0, nullptr, nullptr, &si, &pi);
  if (!ok) {
    // Fallback: try without the explicit application name so that PATH
    // resolution kicks in.
    ok = CreateProcessW(nullptr, wide_cmdline.data(), nullptr, nullptr, TRUE, 0,
                        nullptr, nullptr, &si, &pi);
  }

  if (!ok) {
    DWORD err = GetLastError();
    std::cerr << "CreateProcess failed for '" << args[0] << "': " << err
              << '\n';
    if (read_pipe) CloseHandle(read_pipe);
    if (write_pipe) CloseHandle(write_pipe);
    return result;
  }

  if (capture_stdout) {
    CloseHandle(write_pipe);
    char buffer[4096];
    DWORD read_bytes = 0;
    while (ReadFile(read_pipe, buffer, sizeof(buffer), &read_bytes, nullptr) &&
           read_bytes > 0) {
      result.stdout_text.append(buffer, read_bytes);
    }
    CloseHandle(read_pipe);
  }

  WaitForSingleObject(pi.hProcess, INFINITE);
  DWORD exit_code = 0;
  GetExitCodeProcess(pi.hProcess, &exit_code);
  result.exit_code = static_cast<int>(exit_code);
  CloseHandle(pi.hProcess);
  CloseHandle(pi.hThread);
  return result;
}

#else  // !_WIN32

/// @brief Run @p args as a child process on POSIX systems.
ProcessResult RunProcess(const std::vector<std::string>& args,
                         bool capture_stdout) {
  ProcessResult result;
  if (args.empty()) {
    return result;
  }

  if (g_verbose) {
    std::string joined;
    for (size_t i = 0; i < args.size(); ++i) {
      if (i > 0) joined.push_back(' ');
      joined.append(args[i]);
    }
    std::cerr << "+ " << joined << '\n';
  }

  int pipe_fds[2] = {-1, -1};
  if (capture_stdout && pipe(pipe_fds) != 0) {
    std::perror("pipe");
    return result;
  }

  posix_spawn_file_actions_t actions;
  posix_spawn_file_actions_init(&actions);
  if (capture_stdout) {
    posix_spawn_file_actions_addclose(&actions, pipe_fds[0]);
    posix_spawn_file_actions_adddup2(&actions, pipe_fds[1], STDOUT_FILENO);
    posix_spawn_file_actions_addclose(&actions, pipe_fds[1]);
  }

  std::vector<char*> argv;
  argv.reserve(args.size() + 1);
  for (const auto& a : args) {
    argv.push_back(const_cast<char*>(a.c_str()));
  }
  argv.push_back(nullptr);

  pid_t pid = 0;
  int rc = posix_spawnp(&pid, argv[0], &actions, nullptr, argv.data(), environ);
  posix_spawn_file_actions_destroy(&actions);

  if (rc != 0) {
    std::cerr << "Failed to spawn '" << args[0] << "': " << std::strerror(rc)
              << '\n';
    if (pipe_fds[0] >= 0) close(pipe_fds[0]);
    if (pipe_fds[1] >= 0) close(pipe_fds[1]);
    return result;
  }

  if (capture_stdout) {
    close(pipe_fds[1]);
    char buffer[4096];
    ssize_t n = 0;
    while ((n = read(pipe_fds[0], buffer, sizeof(buffer))) > 0) {
      result.stdout_text.append(buffer, static_cast<size_t>(n));
    }
    close(pipe_fds[0]);
  }

  int status = 0;
  while (waitpid(pid, &status, 0) == -1) {
    if (errno != EINTR) {
      std::perror("waitpid");
      return result;
    }
  }
  if (WIFEXITED(status)) {
    result.exit_code = WEXITSTATUS(status);
  } else {
    result.exit_code = -1;
  }
  return result;
}

#endif  // _WIN32

/// @brief List all files in @p dir matching @p extension.
///
/// @param dir Directory to scan (non-recursive).
/// @param extension File extension including the leading dot.
/// @return Sorted list of absolute paths to matching files.
std::vector<fs::path> FilesWithExtension(const fs::path& dir,
                                         std::string_view extension) {
  std::vector<fs::path> files;
  std::error_code ec;
  if (!fs::is_directory(dir, ec)) {
    return files;
  }
  for (const auto& entry : fs::directory_iterator(dir, ec)) {
    if (ec) break;
    if (entry.is_regular_file() &&
        entry.path().extension().string() == extension) {
      files.push_back(entry.path());
    }
  }
  std::sort(files.begin(), files.end());
  return files;
}

/// @brief Prepare a symlink (or fallback copy) so that @c llvm-cov behaves as
///        if it were invoked under the name @c gcov.
///
/// Clang's @c llvm-cov mimics @c gcov when invoked via a file named @c gcov.
/// A symlink is preferred; if unsupported (e.g., on Windows without the
/// necessary privileges) a hard link, then finally a copy, is used.
///
/// @param gcov_path  The source binary (typically @c COVERAGE_GCOV_PATH).
/// @param link_path  The target link location inside @c COVERAGE_DIR.
/// @return True on success.
bool InitGcov(const fs::path& gcov_path, const fs::path& link_path) {
  std::error_code ec;
  if (!fs::exists(gcov_path, ec)) {
    std::cerr << "GCov does not exist at the given path: '"
              << gcov_path.string() << "'\n";
    return false;
  }

  // Absolute path so the link works regardless of the child's working dir.
  fs::path abs = fs::absolute(gcov_path, ec);
  if (ec) abs = gcov_path;
  ec.clear();
  fs::remove(link_path, ec);

  fs::create_symlink(abs, link_path, ec);
  if (!ec) {
    return true;
  }
  ec.clear();
  fs::create_hard_link(abs, link_path, ec);
  if (!ec) {
    return true;
  }
  ec.clear();
  fs::copy_file(abs, link_path, fs::copy_options::overwrite_existing, ec);
  if (ec) {
    std::cerr << "Failed to prepare gcov link at '" << link_path.string()
              << "': " << ec.message() << '\n';
    return false;
  }
  return true;
}

/// @brief Read every line of @p path into memory.
std::vector<std::string> ReadLines(const fs::path& path) {
  std::vector<std::string> lines;
  std::ifstream in(path);
  std::string line;
  while (std::getline(in, line)) {
    if (!line.empty() && line.back() == '\r') {
      line.pop_back();
    }
    lines.push_back(std::move(line));
  }
  return lines;
}

/// @brief Parse the major version out of a @c gcov (or @c llvm-cov)
///        @c --version banner.
///
/// Matches either
///   @verbatim gcov (Debian 7.3.0-5) 7.3.0 @endverbatim
/// or
///   @verbatim LLVM version 9.0.1 @endverbatim
///
/// @param banner The captured banner text.
/// @return The parsed major version, or -1 on failure.
int ParseGcovMajorVersion(const std::string& banner) {
  auto is_digit = [](char c) { return c >= '0' && c <= '9'; };
  auto extract = [&](size_t start) -> int {
    size_t i = start;
    while (i < banner.size() && is_digit(banner[i])) {
      ++i;
    }
    if (i == start || i >= banner.size() || banner[i] != '.') {
      return -1;
    }
    size_t j = i + 1;
    while (j < banner.size() && is_digit(banner[j])) {
      ++j;
    }
    if (j == i + 1 || j >= banner.size() || banner[j] != '.') {
      return -1;
    }
    try {
      return std::stoi(banner.substr(start, i - start));
    } catch (...) {
      return -1;
    }
  };
  for (size_t i = 0; i < banner.size(); ++i) {
    if (!is_digit(banner[i])) continue;
    if (i > 0 && !std::isspace(static_cast<unsigned char>(banner[i - 1]))) {
      continue;
    }
    int v = extract(i);
    if (v >= 0) {
      return v;
    }
  }
  return -1;
}

/// @brief Append the contents of @p src to @p dest.
///
/// @return True on success.
bool AppendFile(const fs::path& src, std::ofstream& dest) {
  std::ifstream in(src, std::ios::binary);
  if (!in) {
    return false;
  }
  dest << in.rdbuf();
  return dest.good();
}

/// @brief Concatenate every @c *.gcov file in @p dir into @p output_file,
///        deleting the source files on success.
void ConcatenateGcovFiles(const fs::path& dir, const fs::path& output_file) {
  std::ofstream out(output_file, std::ios::binary | std::ios::app);
  if (!out) {
    std::cerr << "Failed to open coverage output for append: "
              << output_file.string() << '\n';
    return;
  }
  for (const auto& p : FilesWithExtension(dir, ".gcov")) {
    if (AppendFile(p, out)) {
      std::error_code ec;
      fs::remove(p, ec);
    }
  }
}

/// @brief Invoke @c llvm-profdata to merge every @c *.profraw in @p
/// coverage_dir
///        into @p output.
///
/// @return Exit code (0 on success).
int MergeProfraw(const std::string& llvm_profdata, const fs::path& coverage_dir,
                 const fs::path& output) {
  std::vector<std::string> cmd = {llvm_profdata, "merge", "-output",
                                  output.string()};
  for (const auto& p : FilesWithExtension(coverage_dir, ".profraw")) {
    cmd.push_back(p.string());
  }
  return NormalizeExit(RunProcess(cmd, /*capture_stdout=*/false).exit_code);
}

/// @brief Copy the @c .gcno file for @p gcno_rel from @p root into the matching
///        location under @p coverage_dir so gcov finds it next to the gcda.
///
/// @return True on success (also when the file is already staged).
bool StageGcnoFile(const fs::path& root, const fs::path& coverage_dir,
                   const fs::path& gcno_rel) {
  fs::path staged = coverage_dir / gcno_rel;
  std::error_code ec;
  if (fs::exists(staged, ec)) return true;
  fs::create_directories(staged.parent_path(), ec);
  fs::copy_file(root / gcno_rel, staged, fs::copy_options::overwrite_existing,
                ec);
  if (ec) {
    std::cerr << "Failed to stage gcno file '" << gcno_rel.string()
              << "': " << ec.message() << '\n';
    return false;
  }
  return true;
}

/// @brief Return every @c *.gcov.json.gz file in @p dir.
std::vector<fs::path> FindJsonGcovOutputs(const fs::path& dir) {
  std::vector<fs::path> out;
  for (auto& p : FilesWithExtension(dir, ".gz")) {
    if (EndsWith(p.filename().string(), ".gcov.json.gz")) {
      out.push_back(std::move(p));
    }
  }
  return out;
}

/// @brief Move @p files into @p dest_dir, falling back to copy + remove for
///        cross-device renames.
void MoveFilesTo(const std::vector<fs::path>& files, const fs::path& dest_dir) {
  std::error_code ec;
  fs::create_directories(dest_dir, ec);
  for (const auto& src : files) {
    fs::path dest = dest_dir / src.filename();
    ec.clear();
    fs::rename(src, dest, ec);
    if (ec) {
      ec.clear();
      fs::copy_file(src, dest, fs::copy_options::overwrite_existing, ec);
      if (!ec) fs::remove(src, ec);
    }
  }
}

}  // namespace

std::optional<std::string> GetEnv(const char* name) {
  const char* value = std::getenv(name);
  if (value == nullptr || value[0] == '\0') {
    return std::nullopt;
  }
  return std::string(value);
}

std::string RequireEnv(const char* name) {
  auto value = GetEnv(name);
  if (!value) {
    std::cerr << "Required environment variable is not set: " << name << '\n';
    std::exit(1);
  }
  return *value;
}

void SetVerbose(bool verbose) { g_verbose = verbose; }

bool UsesLlvm(const fs::path& dir) {
  return !FilesWithExtension(dir, ".profraw").empty();
}

int LlvmCoverageLcov(const fs::path& output_file) {
  std::string llvm_profdata = RequireEnv("LLVM_PROFDATA");
  std::string llvm_cov = RequireEnv("LLVM_COV");
  fs::path coverage_dir = RequireEnv("COVERAGE_DIR");
  fs::path coverage_manifest = RequireEnv("COVERAGE_MANIFEST");

  fs::path data_file = output_file;
  data_file += ".data";

  if (int rc = MergeProfraw(llvm_profdata, coverage_dir, data_file); rc != 0) {
    return rc;
  }

  std::vector<std::string> objects;
  for (const auto& line : ReadLines(coverage_manifest)) {
    if (EndsWith(line, "runtime_objects_list.txt")) {
      for (const auto& obj : ReadLines(line)) {
        std::string trimmed = TrimAscii(obj);
        if (!trimmed.empty()) {
          objects.push_back(std::move(trimmed));
        }
      }
    }
  }

  std::vector<std::string> export_cmd = {
      llvm_cov,           "export",       "-instr-profile",
      data_file.string(), "-format=lcov", "-ignore-filename-regex=^/tmp/.+",
  };
  for (const auto& obj : objects) {
    export_cmd.push_back("-object");
    export_cmd.push_back(obj);
  }

  ProcessResult exported = RunProcess(export_cmd, /*capture_stdout=*/true);
  if (exported.exit_code != 0) {
    return NormalizeExit(exported.exit_code);
  }

  // Emulate `sed 's#/proc/self/cwd/##'` in-process by erasing every occurrence
  // in-place. Bazel's Clang builds embed this prefix under the sandbox.
  std::string& out_text = exported.stdout_text;
  constexpr std::string_view kPrefix = "/proc/self/cwd/";
  for (size_t p = out_text.find(kPrefix); p != std::string::npos;
       p = out_text.find(kPrefix, p)) {
    out_text.erase(p, kPrefix.size());
  }

  std::ofstream out(output_file, std::ios::binary | std::ios::trunc);
  if (!out) {
    std::cerr << "Failed to write coverage output: " << output_file.string()
              << '\n';
    return 1;
  }
  out.write(out_text.data(), static_cast<std::streamsize>(out_text.size()));
  return 0;
}

int LlvmCoverageProfdata(const fs::path& output_file) {
  return MergeProfraw(RequireEnv("LLVM_PROFDATA"), RequireEnv("COVERAGE_DIR"),
                      output_file);
}

int GcovCoverage(const fs::path& output_file) {
  fs::path coverage_dir = RequireEnv("COVERAGE_DIR");
  fs::path coverage_manifest = RequireEnv("COVERAGE_MANIFEST");
  fs::path gcov_path = RequireEnv("COVERAGE_GCOV_PATH");
  fs::path root = RequireEnv("ROOT");
  std::vector<std::string> gcov_options =
      SplitWhitespace(GetEnv("COVERAGE_GCOV_OPTIONS").value_or(""));

  fs::path gcov_link = coverage_dir / "gcov";
  if (!InitGcov(gcov_path, gcov_link)) {
    return 1;
  }

  // Version is a property of the gcov binary, not the file being processed;
  // detect it once and reuse across every manifest entry.
  ProcessResult version =
      RunProcess({gcov_link.string(), "--version"}, /*capture_stdout=*/true);
  int gcov_major = ParseGcovMajorVersion(version.stdout_text);

  fs::path cwd = fs::current_path();
  int last_exit = 0;

  for (const auto& raw_line : ReadLines(coverage_manifest)) {
    std::string line = TrimAscii(raw_line);
    if (!EndsWith(line, "gcno")) continue;

    fs::path gcno_rel(line);
    fs::path gcda = coverage_dir / gcno_rel.parent_path() /
                    (gcno_rel.stem().string() + ".gcda");
    std::error_code ec;
    if (!fs::exists(gcda, ec)) continue;

    if (!StageGcnoFile(root, coverage_dir, gcno_rel)) continue;

    std::vector<std::string> gcov_cmd = {gcov_link.string(), "-i"};
    if (gcov_major > 7) gcov_cmd.push_back("-b");
    for (const auto& opt : gcov_options) gcov_cmd.push_back(opt);
    gcov_cmd.push_back("-o");
    gcov_cmd.push_back(gcda.parent_path().string());
    gcov_cmd.push_back(gcda.string());

    ProcessResult r = RunProcess(gcov_cmd, /*capture_stdout=*/false);
    if (r.exit_code != 0) last_exit = NormalizeExit(r.exit_code);

    // gcov writes its output files into the current working directory. gcov 9
    // and later use compressed JSON; older versions and llvm-cov emit textual
    // .gcov files.
    std::vector<fs::path> json_files = FindJsonGcovOutputs(cwd);
    if (!json_files.empty()) {
      MoveFilesTo(json_files,
                  output_file.parent_path() / gcno_rel.parent_path());
    } else {
      ConcatenateGcovFiles(cwd, output_file);
    }
  }

  std::error_code ec;
  fs::remove(gcov_link, ec);
  return last_exit;
}

}  // namespace bazel_coverage
