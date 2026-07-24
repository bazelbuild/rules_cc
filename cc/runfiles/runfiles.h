// Copyright 2018 The Bazel Authors. All rights reserved.
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

/// @file runfiles.h
/// @brief Runfiles lookup library for Bazel-built C++ binaries and tests.
///
/// ### Usage
///
/// 1. Depend on this runfiles library from your build rule:
///
/// @code{.py}
///   cc_binary(
///       name = "my_binary",
///       ...
///       deps = ["@rules_cc//cc/runfiles"],
///   )
/// @endcode
///
/// 2. Include the runfiles library.
///
/// @code{.cpp}
///   #include "rules_cc/cc/runfiles/runfiles.h"
///
///   using rules_cc::cc::runfiles::Runfiles;
/// @endcode
///
/// 3. Create a #rules_cc::cc::runfiles::Runfiles instance and use
///    #rules_cc::cc::runfiles::Runfiles::Rlocation to look up runfile
///    paths:
///
/// @code{.cpp}
///   int main(int argc, char** argv) {
///     std::string error;
///     std::unique_ptr<Runfiles> runfiles(
///         Runfiles::Create(argv[0], BAZEL_CURRENT_REPOSITORY, &error));
///
///     // Important: if this is a test, use
///     //   Runfiles::CreateForTest(BAZEL_CURRENT_REPOSITORY, &error).
///
///     if (runfiles == nullptr) { /* handle error */ }
///     std::string path =
///         runfiles->Rlocation("my_workspace/path/to/my/data.txt");
///     ...
///   }
/// @endcode
///
/// The `BAZEL_CURRENT_REPOSITORY` macro is available in every target
/// that depends on the runfiles library.
///
/// `Runfiles::Create` uses the runfiles manifest and the runfiles
/// directory from the `RUNFILES_MANIFEST_FILE` and `RUNFILES_DIR`
/// environment variables. If not present, the function looks for the
/// manifest and directory near `argv[0]`, the path of the main
/// program.
///
/// ### Subprocesses
///
/// To start child processes that also need runfiles, iterate
/// #rules_cc::cc::runfiles::Runfiles::EnvVars and set the returned
/// key/value pairs in the child's environment.
///
/// ### Sharing / lifetime
///
/// Each `Runfiles::Create` call parses the manifest and `_repo_mapping`
/// from disk and returns an instance that fully owns its parsed data.
/// Callers that want to reuse a parse across scopes / threads should
/// hold the returned #Runfiles via a `std::shared_ptr<Runfiles>`
/// themselves — the library does not maintain a process-wide cache.
///
/// ### Thread safety
///
/// Different #Runfiles instances are independent. A single instance is
/// safe for parallel #Rlocation reads (the parsed state is immutable
/// after construction); mixing reads with destruction is the caller's
/// problem — same contract as `std::vector`.

#ifndef RULES_CC_CC_RUNFILES_RUNFILES_H_
#define RULES_CC_CC_RUNFILES_RUNFILES_H_

#include <functional>
#include <string>
#include <utility>
#include <vector>

// Opaque C handle owned by every #Runfiles instance. Forward-declared
// here so the C header does not need to be included by C++ callers.
extern "C" {
struct rf_runfiles;
}

namespace rules_cc {
namespace cc {
namespace runfiles {

/// Runfiles lookup for Bazel-built C++ binaries and tests.
///
/// Thin RAII wrapper over the underlying pure-C runfiles library (see
/// `runfiles_c.h`); every lookup delegates to the C implementation so
/// the two languages share exactly one parser / lookup / repo-mapping
/// implementation.
class Runfiles {
 public:
  virtual ~Runfiles();

  /// Create a #Runfiles instance for a `cc_test`.
  ///
  /// Reads `RUNFILES_MANIFEST_FILE` and `TEST_SRCDIR` from the
  /// environment.
  ///
  /// @param error Optional out-pointer for a human-readable error
  ///   message on failure.
  /// @return New instance on success (owned by caller), or `nullptr`
  ///   on error.
  static Runfiles* CreateForTest(std::string* error = nullptr);

  /// Create a #Runfiles instance for a `cc_test` with an explicit
  /// source repository.
  static Runfiles* CreateForTest(const std::string& source_repository,
                                 std::string* error = nullptr);

  /// Create a #Runfiles instance for a `cc_binary` or `cc_library`.
  ///
  /// Reads `RUNFILES_MANIFEST_FILE` and `RUNFILES_DIR` from the
  /// environment; if either is empty, falls back to the other or to
  /// argv0-based discovery.
  static Runfiles* Create(const std::string& argv0,
                          std::string* error = nullptr);

  /// Overload accepting an explicit source repository.
  static Runfiles* Create(const std::string& argv0,
                          const std::string& source_repository,
                          std::string* error = nullptr);

  /// Overload that lets callers pin the manifest and directory paths
  /// instead of consulting the environment.
  static Runfiles* Create(const std::string& argv0,
                          const std::string& runfiles_manifest_file,
                          const std::string& runfiles_dir,
                          std::string* error = nullptr);

  /// Full-parameter overload.
  static Runfiles* Create(const std::string& argv0,
                          const std::string& runfiles_manifest_file,
                          const std::string& runfiles_dir,
                          const std::string& source_repository,
                          std::string* error = nullptr);

  /// Resolve the runtime path of a runfile using this instance's
  /// default source repository.
  std::string Rlocation(const std::string& path) const;

  /// Resolve a runfile using a per-call source repository override.
  std::string Rlocation(const std::string& path,
                        const std::string& source_repository) const;

  /// Environment variables to publish to subprocesses (populated once
  /// at construction from the C library's `rf_env_var`).
  const std::vector<std::pair<std::string, std::string> >& EnvVars() const {
    return envvars_;
  }

 private:
  Runfiles(rf_runfiles* handle, std::string source_repository,
           std::vector<std::pair<std::string, std::string> > envvars)
      : handle_(handle),
        source_repository_(std::move(source_repository)),
        envvars_(std::move(envvars)) {}
  Runfiles(const Runfiles&) = delete;
  Runfiles(Runfiles&&) = delete;
  Runfiles& operator=(const Runfiles&) = delete;
  Runfiles& operator=(Runfiles&&) = delete;

  rf_runfiles* const handle_;
  const std::string source_repository_;
  const std::vector<std::pair<std::string, std::string> > envvars_;
};

/// Test-only helpers.
///
/// Do NOT use these outside of `runfiles_test.cc`; they are exposed as
/// part of the public API purely for the benefit of the unit tests and
/// may change without notice.
namespace testing {

/// Test-only: compute the path of the runfiles manifest and directory.
///
/// If the method finds both a valid manifest and valid directory
/// according to @p is_runfiles_manifest and @p is_runfiles_directory,
/// it sets the corresponding output variables and returns `true`. If
/// it finds only one, it sets that one and clears the other, still
/// returning `true`. If it finds neither, it clears both and returns
/// `false`.
bool TestOnly_PathsFrom(
    const std::string& argv0, std::string runfiles_manifest_file,
    std::string runfiles_dir,
    std::function<bool(const std::string&)> is_runfiles_manifest,
    std::function<bool(const std::string&)> is_runfiles_directory,
    std::string* out_manifest, std::string* out_directory);

/// Test-only: return `true` if @p path is an absolute Unix or Windows
/// path.
bool TestOnly_IsAbsolute(const std::string& path);

}  // namespace testing
}  // namespace runfiles
}  // namespace cc
}  // namespace rules_cc

#endif  // RULES_CC_CC_RUNFILES_RUNFILES_H_
