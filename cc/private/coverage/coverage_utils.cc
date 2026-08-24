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
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#else
#include <dirent.h>
#include <spawn.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
extern char** environ;
#endif

namespace bazel_coverage {

namespace {

/// @brief When true, log every external command that is executed.
bool g_verbose = false;

#ifdef _WIN32
/// @brief The separator inserted by @c JoinPath.
const char kPathSeparator = '\\';
#else
/// @brief The separator inserted by @c JoinPath.
const char kPathSeparator = '/';
#endif

/// @brief Return true when @p c separates path components on this platform.
bool IsPathSeparator(char c) {
#ifdef _WIN32
  return c == '/' || c == '\\';
#else
  return c == '/';
#endif
}

/// @brief Return true when @p path is rooted rather than relative.
bool IsAbsolute(const std::string& path) {
  if (path.empty()) {
    return false;
  }
  if (IsPathSeparator(path[0])) {
    return true;
  }
#ifdef _WIN32
  // Drive-qualified paths such as "C:\foo".
  return path.size() >= 3 && path[1] == ':' && IsPathSeparator(path[2]);
#else
  return false;
#endif
}

/// @brief Return the index of the last path separator in @p path, or
///        @c std::string::npos when there is none.
size_t LastSeparator(const std::string& path) {
#ifdef _WIN32
  return path.find_last_of("/\\");
#else
  return path.find_last_of('/');
#endif
}

/// @brief Return everything before the final component of @p path.
std::string ParentPath(const std::string& path) {
  size_t pos = LastSeparator(path);
  if (pos == std::string::npos) {
    return std::string();
  }
  // Preserve the root separator so that "/foo" yields "/" rather than "".
  return pos == 0 ? std::string(1, path[0]) : path.substr(0, pos);
}

/// @brief Return the final component of @p path.
std::string BaseName(const std::string& path) {
  size_t pos = LastSeparator(path);
  return pos == std::string::npos ? path : path.substr(pos + 1);
}

/// @brief Return the final extension of @p path, including the leading dot.
std::string Extension(const std::string& path) {
  std::string name = BaseName(path);
  size_t dot = name.rfind('.');
  // A leading dot denotes a hidden file, not an extension.
  if (dot == std::string::npos || dot == 0) {
    return std::string();
  }
  return name.substr(dot);
}

/// @brief Return the final component of @p path without its extension.
std::string Stem(const std::string& path) {
  std::string name = BaseName(path);
  return name.substr(0, name.size() - Extension(path).size());
}

/// @brief Return true when @p s ends with @p suffix.
bool EndsWith(const std::string& s, const std::string& suffix) {
  return s.size() >= suffix.size() &&
         s.compare(s.size() - suffix.size(), suffix.size(), suffix) == 0;
}

/// @brief Trim ASCII whitespace and carriage returns from both ends.
std::string TrimAscii(const std::string& s) {
  const char* kSpaces = " \t\r\n";
  size_t begin = s.find_first_not_of(kSpaces);
  if (begin == std::string::npos) {
    return std::string();
  }
  return s.substr(begin, s.find_last_not_of(kSpaces) - begin + 1);
}

/// @brief Split a string on ASCII whitespace, dropping empty tokens.
std::vector<std::string> SplitWhitespace(const std::string& s) {
  std::vector<std::string> out;
  std::istringstream iss(s);
  std::string tok;
  while (iss >> tok) {
    out.push_back(tok);
  }
  return out;
}

/// @brief Append the contents of @p src to the already-open @p dest.
///
/// Declared up front so the POSIX @c CopyFileTo below can share it.
bool AppendFile(const std::string& src, std::ofstream& dest);

/// @brief Result of running an external process.
struct ProcessResult {
  /// @brief Exit code of the child. Defaults to a generic failure so that a
  ///        process which never spawned, or which died from a signal, reports
  ///        an error the caller can return directly.
  int exit_code = 1;
  /// @brief Captured standard output when requested; empty otherwise.
  std::string stdout_text;
};

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
  SECURITY_ATTRIBUTES sa = {sizeof(sa), nullptr, TRUE};
  if (capture_stdout) {
    if (!CreatePipe(&read_pipe, &write_pipe, &sa, 0)) {
      std::cerr << "CreatePipe failed: " << GetLastError() << '\n';
      return result;
    }
    SetHandleInformation(read_pipe, HANDLE_FLAG_INHERIT, 0);
  }

  STARTUPINFOA si;
  std::memset(&si, 0, sizeof(si));
  si.cb = sizeof(si);
  si.dwFlags = STARTF_USESTDHANDLES;
  si.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
  si.hStdError = GetStdHandle(STD_ERROR_HANDLE);
  si.hStdOutput = capture_stdout ? write_pipe : GetStdHandle(STD_OUTPUT_HANDLE);

  PROCESS_INFORMATION pi;
  std::memset(&pi, 0, sizeof(pi));
  std::vector<char> mutable_cmdline(cmdline.begin(), cmdline.end());
  mutable_cmdline.push_back('\0');
  BOOL ok = CreateProcessA(args[0].c_str(), &mutable_cmdline[0], nullptr,
                           nullptr, TRUE, 0, nullptr, nullptr, &si, &pi);
  if (!ok) {
    // Fallback: try without the explicit application name so that PATH
    // resolution kicks in.
    std::copy(cmdline.begin(), cmdline.end(), mutable_cmdline.begin());
    ok = CreateProcessA(nullptr, &mutable_cmdline[0], nullptr, nullptr, TRUE, 0,
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

/// @brief Return true when @p path names an existing file or directory.
bool PathExists(const std::string& path) {
  return GetFileAttributesA(path.c_str()) != INVALID_FILE_ATTRIBUTES;
}

/// @brief Return true when @p path names an existing directory.
bool IsDirectory(const std::string& path) {
  DWORD attrs = GetFileAttributesA(path.c_str());
  return attrs != INVALID_FILE_ATTRIBUTES &&
         (attrs & FILE_ATTRIBUTE_DIRECTORY) != 0;
}

/// @brief Return the names of the non-directory entries directly in @p dir.
std::vector<std::string> ListDirectory(const std::string& dir) {
  std::vector<std::string> names;
  WIN32_FIND_DATAA data;
  HANDLE handle = FindFirstFileA(JoinPath(dir, "*").c_str(), &data);
  if (handle == INVALID_HANDLE_VALUE) {
    return names;
  }
  do {
    if ((data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) == 0) {
      names.push_back(data.cFileName);
    }
  } while (FindNextFileA(handle, &data));
  FindClose(handle);
  return names;
}

/// @brief Create the single directory @p path. Succeeds if it already exists.
bool MakeDirectory(const std::string& path) {
  return CreateDirectoryA(path.c_str(), nullptr) != 0 ||
         GetLastError() == ERROR_ALREADY_EXISTS;
}

/// @brief Delete the file at @p path.
bool RemoveFile(const std::string& path) {
  return DeleteFileA(path.c_str()) != 0;
}

/// @brief Copy @p src over @p dest, preserving the permission bits.
bool CopyFileTo(const std::string& src, const std::string& dest) {
  return CopyFileA(src.c_str(), dest.c_str(), /*bFailIfExists=*/FALSE) != 0;
}

/// @brief Rename @p src to @p dest, replacing @p dest if it exists.
bool RenameFile(const std::string& src, const std::string& dest) {
  return MoveFileExA(src.c_str(), dest.c_str(), MOVEFILE_REPLACE_EXISTING) != 0;
}

/// @brief Create @p link pointing at @p target, preferring a symlink and
///        falling back to a hard link.
bool MakeLink(const std::string& target, const std::string& link) {
  // Creating symlinks requires either elevation or Developer Mode, so a
  // failure here is expected on stock Windows configurations.
  if (CreateSymbolicLinkA(link.c_str(), target.c_str(), 0) != 0) {
    return true;
  }
  return CreateHardLinkA(link.c_str(), target.c_str(), nullptr) != 0;
}

/// @brief Return the process' current working directory.
std::string CurrentPath() {
  DWORD size = GetCurrentDirectoryA(0, nullptr);
  if (size == 0) {
    return std::string();
  }
  std::vector<char> buffer(size);
  DWORD written = GetCurrentDirectoryA(size, &buffer[0]);
  return std::string(&buffer[0], written);
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
  for (size_t i = 0; i < args.size(); ++i) {
    argv.push_back(const_cast<char*>(args[i].c_str()));
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
  }
  return result;
}

/// @brief Return true when @p path names an existing file or directory.
bool PathExists(const std::string& path) {
  struct stat info;
  return stat(path.c_str(), &info) == 0;
}

/// @brief Return true when @p path names an existing directory.
bool IsDirectory(const std::string& path) {
  struct stat info;
  return stat(path.c_str(), &info) == 0 && S_ISDIR(info.st_mode);
}

/// @brief Return the names of the non-directory entries directly in @p dir.
std::vector<std::string> ListDirectory(const std::string& dir) {
  std::vector<std::string> names;
  DIR* handle = opendir(dir.c_str());
  if (handle == nullptr) {
    return names;
  }
  while (struct dirent* entry = readdir(handle)) {
    std::string name = entry->d_name;
    if (name == "." || name == "..") {
      continue;
    }
    if (!IsDirectory(JoinPath(dir, name))) {
      names.push_back(name);
    }
  }
  closedir(handle);
  return names;
}

/// @brief Create the single directory @p path. Succeeds if it already exists.
bool MakeDirectory(const std::string& path) {
  return mkdir(path.c_str(), 0777) == 0 || errno == EEXIST;
}

/// @brief Delete the file at @p path.
bool RemoveFile(const std::string& path) { return ::remove(path.c_str()) == 0; }

/// @brief Copy @p src over @p dest, preserving the permission bits.
///
/// The mode is carried over so that the @c gcov binary stays executable when
/// @c InitGcov has to fall back from linking to copying.
bool CopyFileTo(const std::string& src, const std::string& dest) {
  std::ofstream out(dest.c_str(), std::ios::binary | std::ios::trunc);
  if (!out || !AppendFile(src, out)) {
    return false;
  }
  out.close();
  struct stat info;
  if (stat(src.c_str(), &info) == 0) {
    chmod(dest.c_str(), info.st_mode & 07777);
  }
  return true;
}

/// @brief Rename @p src to @p dest, replacing @p dest if it exists.
bool RenameFile(const std::string& src, const std::string& dest) {
  return ::rename(src.c_str(), dest.c_str()) == 0;
}

/// @brief Create @p link pointing at @p target, preferring a symlink and
///        falling back to a hard link.
bool MakeLink(const std::string& target, const std::string& link) {
  return symlink(target.c_str(), link.c_str()) == 0 ||
         ::link(target.c_str(), link.c_str()) == 0;
}

/// @brief Return the process' current working directory.
std::string CurrentPath() {
  std::vector<char> buffer(4096);
  for (;;) {
    if (getcwd(&buffer[0], buffer.size()) != nullptr) {
      return std::string(&buffer[0]);
    }
    if (errno != ERANGE) {
      return std::string();
    }
    buffer.resize(buffer.size() * 2);
  }
}

#endif  // _WIN32

/// @brief Create @p path along with any missing parent directories.
bool CreateDirectories(const std::string& path) {
  if (path.empty() || IsDirectory(path)) {
    return true;
  }
  std::string parent = ParentPath(path);
  if (!parent.empty() && parent != path && !CreateDirectories(parent)) {
    return false;
  }
  return MakeDirectory(path);
}

/// @brief Resolve @p path against the current working directory if relative.
std::string AbsolutePath(const std::string& path) {
  return IsAbsolute(path) ? path : JoinPath(CurrentPath(), path);
}

/// @brief Pick the entries of @p names ending in @p suffix.
///
/// Matching the whole suffix rather than just the final extension lets callers
/// ask for multi-part names such as @c ".gcov.json.gz" directly. Taking the
/// listing as a parameter lets a caller that needs two different suffixes scan
/// the directory once.
///
/// @param dir Directory the names came from; prefixed onto each result.
/// @param names Directory entries as returned by @c ListDirectory.
/// @param suffix Name suffix to match, including the leading dot.
/// @return Sorted list of paths to matching files.
std::vector<std::string> SelectBySuffix(const std::string& dir,
                                        const std::vector<std::string>& names,
                                        const std::string& suffix) {
  std::vector<std::string> files;
  for (size_t i = 0; i < names.size(); ++i) {
    if (EndsWith(names[i], suffix)) {
      files.push_back(JoinPath(dir, names[i]));
    }
  }
  std::sort(files.begin(), files.end());
  return files;
}

/// @brief List all files directly in @p dir whose name ends with @p suffix.
///
/// @param dir Directory to scan (non-recursive).
/// @param suffix Name suffix to match, including the leading dot.
/// @return Sorted list of paths to matching files.
std::vector<std::string> FilesWithSuffix(const std::string& dir,
                                         const std::string& suffix) {
  // ListDirectory yields nothing when `dir` is not a directory, so there is no
  // need to stat it first.
  return SelectBySuffix(dir, ListDirectory(dir), suffix);
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
bool InitGcov(const std::string& gcov_path, const std::string& link_path) {
  if (!PathExists(gcov_path)) {
    std::cerr << "GCov does not exist at the given path: '" << gcov_path
              << "'\n";
    return false;
  }

  // Absolute path so the link works regardless of the child's working dir.
  std::string target = AbsolutePath(gcov_path);
  RemoveFile(link_path);
  if (MakeLink(target, link_path)) {
    return true;
  }
  if (!CopyFileTo(target, link_path)) {
    std::cerr << "Failed to prepare gcov link at '" << link_path << "'\n";
    return false;
  }
  return true;
}

/// @brief Read every line of @p path into memory.
std::vector<std::string> ReadLines(const std::string& path) {
  std::vector<std::string> lines;
  std::ifstream in(path.c_str());
  std::string line;
  while (std::getline(in, line)) {
    if (!line.empty() && line[line.size() - 1] == '\r') {
      line.erase(line.size() - 1);
    }
    lines.push_back(line);
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
  // Accept only "<major>.<minor>." so that a bare year or build number in the
  // banner is not mistaken for a version.
  for (size_t start = 0; start < banner.size(); ++start) {
    if (!std::isdigit(static_cast<unsigned char>(banner[start]))) {
      continue;
    }
    if (start > 0 &&
        !std::isspace(static_cast<unsigned char>(banner[start - 1]))) {
      continue;
    }
    size_t i = start;
    while (i < banner.size() &&
           std::isdigit(static_cast<unsigned char>(banner[i]))) {
      ++i;
    }
    if (i >= banner.size() || banner[i] != '.') {
      continue;
    }
    size_t j = i + 1;
    while (j < banner.size() &&
           std::isdigit(static_cast<unsigned char>(banner[j]))) {
      ++j;
    }
    if (j == i + 1 || j >= banner.size() || banner[j] != '.') {
      continue;
    }
    return std::atoi(banner.substr(start, i - start).c_str());
  }
  return -1;
}

/// @brief Append the contents of @p src to @p dest.
///
/// @return True on success.
bool AppendFile(const std::string& src, std::ofstream& dest) {
  std::ifstream in(src.c_str(), std::ios::binary);
  if (!in) {
    return false;
  }
  // Inserting an empty streambuf sets failbit, so skip empty sources.
  if (in.peek() != std::ifstream::traits_type::eof()) {
    dest << in.rdbuf();
  }
  return dest.good();
}

/// @brief Concatenate @p files into @p output_file, deleting each source file
///        on success.
void ConcatenateGcovFiles(const std::vector<std::string>& files,
                          const std::string& output_file) {
  std::ofstream out(output_file.c_str(), std::ios::binary | std::ios::app);
  if (!out) {
    std::cerr << "Failed to open coverage output for append: " << output_file
              << '\n';
    return;
  }
  for (size_t i = 0; i < files.size(); ++i) {
    if (AppendFile(files[i], out)) {
      RemoveFile(files[i]);
    }
  }
}

/// @brief Invoke @c llvm-profdata to merge every @c *.profraw in
///        @p coverage_dir into @p output.
///
/// @return Exit code (0 on success).
int MergeProfraw(const std::string& llvm_profdata,
                 const std::string& coverage_dir, const std::string& output) {
  std::vector<std::string> cmd;
  cmd.push_back(llvm_profdata);
  cmd.push_back("merge");
  cmd.push_back("-output");
  cmd.push_back(output);
  std::vector<std::string> profraws = FilesWithSuffix(coverage_dir, ".profraw");
  cmd.insert(cmd.end(), profraws.begin(), profraws.end());
  return RunProcess(cmd, /*capture_stdout=*/false).exit_code;
}

/// @brief Copy the @c .gcno file for @p gcno_rel from @p root into the matching
///        location under @p coverage_dir so gcov finds it next to the gcda.
///
/// @return True on success (also when the file is already staged).
bool StageGcnoFile(const std::string& root, const std::string& coverage_dir,
                   const std::string& gcno_rel) {
  std::string staged = JoinPath(coverage_dir, gcno_rel);
  if (PathExists(staged)) {
    return true;
  }
  if (!CreateDirectories(ParentPath(staged)) ||
      !CopyFileTo(JoinPath(root, gcno_rel), staged)) {
    std::cerr << "Failed to stage gcno file '" << gcno_rel << "'\n";
    return false;
  }
  return true;
}

/// @brief Move @p files into @p dest_dir, falling back to copy + remove for
///        cross-device renames.
void MoveFilesTo(const std::vector<std::string>& files,
                 const std::string& dest_dir) {
  CreateDirectories(dest_dir);
  for (size_t i = 0; i < files.size(); ++i) {
    std::string dest = JoinPath(dest_dir, BaseName(files[i]));
    if (RenameFile(files[i], dest)) {
      continue;
    }
    if (CopyFileTo(files[i], dest)) {
      RemoveFile(files[i]);
    }
  }
}

}  // namespace

std::string JoinPath(const std::string& lhs, const std::string& rhs) {
  if (lhs.empty() || IsAbsolute(rhs)) {
    return rhs;
  }
  if (rhs.empty()) {
    return lhs;
  }
  std::string out = lhs;
  if (!IsPathSeparator(out[out.size() - 1])) {
    out.push_back(kPathSeparator);
  }
  out.append(rhs);
  return out;
}

std::string GetEnvOr(const char* name, const std::string& default_value) {
  const char* value = std::getenv(name);
  if (value == nullptr || value[0] == '\0') {
    return default_value;
  }
  return std::string(value);
}

bool HasEnv(const char* name) { return !GetEnvOr(name, "").empty(); }

std::string RequireEnv(const char* name) {
  std::string value = GetEnvOr(name, "");
  if (value.empty()) {
    std::cerr << "Required environment variable is not set: " << name << '\n';
    std::exit(1);
  }
  return value;
}

void SetVerbose(bool verbose) { g_verbose = verbose; }

bool UsesLlvm(const std::string& dir) {
  return !FilesWithSuffix(dir, ".profraw").empty();
}

int LlvmCoverageLcov(const std::string& coverage_dir,
                     const std::string& output_file) {
  std::string llvm_profdata = RequireEnv("LLVM_PROFDATA");
  std::string llvm_cov = RequireEnv("LLVM_COV");
  std::string coverage_manifest = RequireEnv("COVERAGE_MANIFEST");

  std::string data_file = output_file + ".data";

  int merge_exit = MergeProfraw(llvm_profdata, coverage_dir, data_file);
  if (merge_exit != 0) {
    return merge_exit;
  }

  std::vector<std::string> objects;
  std::vector<std::string> manifest = ReadLines(coverage_manifest);
  for (size_t i = 0; i < manifest.size(); ++i) {
    if (!EndsWith(manifest[i], "runtime_objects_list.txt")) {
      continue;
    }
    std::vector<std::string> listed = ReadLines(manifest[i]);
    for (size_t j = 0; j < listed.size(); ++j) {
      std::string trimmed = TrimAscii(listed[j]);
      if (!trimmed.empty()) {
        objects.push_back(trimmed);
      }
    }
  }

  std::vector<std::string> export_cmd;
  export_cmd.push_back(llvm_cov);
  export_cmd.push_back("export");
  export_cmd.push_back("-instr-profile");
  export_cmd.push_back(data_file);
  export_cmd.push_back("-format=lcov");
  export_cmd.push_back("-ignore-filename-regex=^/tmp/.+");
  for (size_t i = 0; i < objects.size(); ++i) {
    export_cmd.push_back("-object");
    export_cmd.push_back(objects[i]);
  }

  ProcessResult exported = RunProcess(export_cmd, /*capture_stdout=*/true);
  if (exported.exit_code != 0) {
    return exported.exit_code;
  }

  // Emulate `sed 's#/proc/self/cwd/##'` in one pass. Bazel's Clang builds embed
  // this prefix under the sandbox once per source file, so erasing in place
  // would shift the tail of the whole report for every occurrence.
  const std::string& raw = exported.stdout_text;
  const std::string kPrefix = "/proc/self/cwd/";
  std::string out_text;
  out_text.reserve(raw.size());
  size_t copied = 0;
  for (size_t p = raw.find(kPrefix); p != std::string::npos;
       p = raw.find(kPrefix, copied)) {
    out_text.append(raw, copied, p - copied);
    copied = p + kPrefix.size();
  }
  out_text.append(raw, copied, std::string::npos);

  std::ofstream out(output_file.c_str(), std::ios::binary | std::ios::trunc);
  if (!out) {
    std::cerr << "Failed to write coverage output: " << output_file << '\n';
    return 1;
  }
  out.write(out_text.data(), static_cast<std::streamsize>(out_text.size()));
  return 0;
}

int LlvmCoverageProfdata(const std::string& coverage_dir,
                         const std::string& output_file) {
  return MergeProfraw(RequireEnv("LLVM_PROFDATA"), coverage_dir, output_file);
}

int GcovCoverage(const std::string& coverage_dir,
                 const std::string& output_file) {
  std::string coverage_manifest = RequireEnv("COVERAGE_MANIFEST");
  std::string gcov_path = RequireEnv("COVERAGE_GCOV_PATH");
  std::string root = RequireEnv("ROOT");
  std::vector<std::string> gcov_options =
      SplitWhitespace(GetEnvOr("COVERAGE_GCOV_OPTIONS", ""));

  std::string gcov_link = JoinPath(coverage_dir, "gcov");
  if (!InitGcov(gcov_path, gcov_link)) {
    return 1;
  }

  // Version is a property of the gcov binary, not the file being processed;
  // detect it once and reuse across every manifest entry.
  std::vector<std::string> version_cmd;
  version_cmd.push_back(gcov_link);
  version_cmd.push_back("--version");
  ProcessResult version = RunProcess(version_cmd, /*capture_stdout=*/true);
  int gcov_major = ParseGcovMajorVersion(version.stdout_text);

  std::string cwd = CurrentPath();
  int last_exit = 0;

  std::vector<std::string> manifest = ReadLines(coverage_manifest);
  for (size_t i = 0; i < manifest.size(); ++i) {
    std::string gcno_rel = TrimAscii(manifest[i]);
    if (!EndsWith(gcno_rel, "gcno")) {
      continue;
    }

    std::string gcda = JoinPath(JoinPath(coverage_dir, ParentPath(gcno_rel)),
                                Stem(gcno_rel) + ".gcda");
    if (!PathExists(gcda)) {
      continue;
    }
    if (!StageGcnoFile(root, coverage_dir, gcno_rel)) {
      continue;
    }

    std::vector<std::string> gcov_cmd;
    gcov_cmd.push_back(gcov_link);
    gcov_cmd.push_back("-i");
    if (gcov_major > 7) {
      gcov_cmd.push_back("-b");
    }
    gcov_cmd.insert(gcov_cmd.end(), gcov_options.begin(), gcov_options.end());
    gcov_cmd.push_back("-o");
    gcov_cmd.push_back(ParentPath(gcda));
    gcov_cmd.push_back(gcda);

    ProcessResult r = RunProcess(gcov_cmd, /*capture_stdout=*/false);
    if (r.exit_code != 0) {
      last_exit = r.exit_code;
    }

    // gcov writes its output files into the current working directory. gcov 9
    // and later use compressed JSON; older versions and llvm-cov emit textual
    // .gcov files. A single listing answers both questions.
    std::vector<std::string> produced = ListDirectory(cwd);
    std::vector<std::string> json_files =
        SelectBySuffix(cwd, produced, ".gcov.json.gz");
    if (!json_files.empty()) {
      MoveFilesTo(json_files,
                  JoinPath(ParentPath(output_file), ParentPath(gcno_rel)));
    } else {
      ConcatenateGcovFiles(SelectBySuffix(cwd, produced, ".gcov"), output_file);
    }
  }

  RemoveFile(gcov_link);
  return last_exit;
}

}  // namespace bazel_coverage
