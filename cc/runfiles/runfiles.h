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
/// @brief Runfiles lookup for Bazel-built C++ binaries and tests.
///
/// 1. Depend on the library:
///
/// @code{.py}
///   cc_binary(
///       name = "my_binary",
///       ...
///       deps = ["@rules_cc//cc/runfiles"],
///   )
/// @endcode
///
/// 2. Create a #rules_cc::cc::runfiles::Runfiles and look up paths with
///    #rules_cc::cc::runfiles::Runfiles::Rlocation:
///
/// @code{.cpp}
///   #include "rules_cc/cc/runfiles/runfiles.h"
///
///   using rules_cc::cc::runfiles::Runfiles;
///
///   int main(int argc, char** argv) {
///     std::string error;
///     std::unique_ptr<Runfiles> runfiles(
///         Runfiles::Create(argv[0], BAZEL_CURRENT_REPOSITORY, &error));
///
///     // In a test, use
///     //   Runfiles::CreateForTest(BAZEL_CURRENT_REPOSITORY, &error).
///
///     if (runfiles == nullptr) { /* handle error */ }
///     std::string path =
///         runfiles->Rlocation("my_workspace/path/to/my/data.txt");
///     ...
///   }
/// @endcode
///
/// `BAZEL_CURRENT_REPOSITORY` is defined in every target that depends on
/// the runfiles library.
///
/// To start child processes that also need runfiles, set the key/value
/// pairs from #rules_cc::cc::runfiles::Runfiles::EnvVars in the child's
/// environment.
///
/// Instances are independent and own their parsed state. An instance may be
/// read concurrently from several threads, but must not be destroyed while
/// a lookup is in flight.

#ifndef RULES_CC_CC_RUNFILES_RUNFILES_H_
#define RULES_CC_CC_RUNFILES_RUNFILES_H_

#include <functional>
#include <memory>
#include <string>
#include <utility>
#include <vector>

// Forward declarations from runfiles_c.h, so that this header does not
// expose the C API. rf_free is the shared_ptr deleter for handle_.
extern "C" {
struct rf_runfiles;
void rf_free(struct rf_runfiles*);
}

namespace rules_cc {
namespace cc {
namespace runfiles {

/// Runfiles lookup for Bazel-built C++ binaries and tests. Wraps the C
/// library in `runfiles_c.h`.
class Runfiles {
 public:
  virtual ~Runfiles();

  /// Creates an instance for a `cc_test` from `RUNFILES_MANIFEST_FILE` and
  /// `TEST_SRCDIR`, with the main repository as default source repository.
  ///
  /// @param error Optional out-parameter for an error message.
  /// @return New instance owned by the caller, or `nullptr` on error.
  static Runfiles* CreateForTest(std::string* error = nullptr);

  /// Creates an instance for a `cc_test` from `RUNFILES_MANIFEST_FILE` and
  /// `TEST_SRCDIR`.
  ///
  /// @param source_repository Canonical name of the default source
  ///   repository; `""` is the main repository.
  /// @param error Optional out-parameter for an error message.
  /// @return New instance owned by the caller, or `nullptr` on error.
  static Runfiles* CreateForTest(const std::string& source_repository,
                                 std::string* error = nullptr);

  /// Creates an instance for a `cc_binary` or `cc_library` from
  /// `RUNFILES_MANIFEST_FILE` and `RUNFILES_DIR`, falling back to discovery
  /// next to @p argv0, with the main repository as default source
  /// repository.
  ///
  /// @param argv0 `argv[0]`, or `""` if unknown.
  /// @param error Optional out-parameter for an error message.
  /// @return New instance owned by the caller, or `nullptr` on error.
  static Runfiles* Create(const std::string& argv0,
                          std::string* error = nullptr);

  /// Creates an instance for a `cc_binary` or `cc_library` from
  /// `RUNFILES_MANIFEST_FILE` and `RUNFILES_DIR`, falling back to discovery
  /// next to @p argv0.
  ///
  /// @param argv0 `argv[0]`, or `""` if unknown.
  /// @param source_repository Canonical name of the default source
  ///   repository; `""` is the main repository.
  /// @param error Optional out-parameter for an error message.
  /// @return New instance owned by the caller, or `nullptr` on error.
  static Runfiles* Create(const std::string& argv0,
                          const std::string& source_repository,
                          std::string* error = nullptr);

  /// Creates an instance from explicit paths, with the main repository as
  /// default source repository.
  ///
  /// @param argv0 `argv[0]`, or `""` if unknown.
  /// @param runfiles_manifest_file Manifest path, or `""` to derive it from
  ///   @p runfiles_dir or @p argv0.
  /// @param runfiles_dir Runfiles directory, or `""` to derive it from
  ///   @p runfiles_manifest_file or @p argv0.
  /// @param error Optional out-parameter for an error message.
  /// @return New instance owned by the caller, or `nullptr` on error.
  static Runfiles* Create(const std::string& argv0,
                          const std::string& runfiles_manifest_file,
                          const std::string& runfiles_dir,
                          std::string* error = nullptr);

  /// Creates an instance from explicit paths.
  ///
  /// @param argv0 `argv[0]`, or `""` if unknown.
  /// @param runfiles_manifest_file Manifest path, or `""` to derive it from
  ///   @p runfiles_dir or @p argv0.
  /// @param runfiles_dir Runfiles directory, or `""` to derive it from
  ///   @p runfiles_manifest_file or @p argv0.
  /// @param source_repository Canonical name of the default source
  ///   repository; `""` is the main repository.
  /// @param error Optional out-parameter for an error message.
  /// @return New instance owned by the caller, or `nullptr` on error.
  static Runfiles* Create(const std::string& argv0,
                          const std::string& runfiles_manifest_file,
                          const std::string& runfiles_dir,
                          const std::string& source_repository,
                          std::string* error = nullptr);

  /// Resolves a runfile using the default source repository.
  ///
  /// @param path Runfiles-root-relative path.
  /// @return Runtime path, which may not exist, or `""` if @p path is
  ///   invalid or unknown.
  std::string Rlocation(const std::string& path) const;

  /// Resolves a runfile.
  ///
  /// @param path Runfiles-root-relative path.
  /// @param source_repository Canonical name of the source repository to
  ///   apply `_repo_mapping` for; `""` is the main repository.
  /// @return Runtime path, which may not exist, or `""` if @p path is
  ///   invalid or unknown.
  std::string Rlocation(const std::string& path,
                        const std::string& source_repository) const;

  /// @return Environment variables a subprocess needs in order to find the
  ///   same runfiles.
  const std::vector<std::pair<std::string, std::string> >& EnvVars() const {
    return envvars_;
  }

  /// Derives an instance that shares this instance's parsed state. This
  /// instance remains valid.
  ///
  /// @param source_repository Canonical name of the new instance's default
  ///   source repository; `""` is the main repository.
  /// @return New instance owned by the caller.
  std::unique_ptr<Runfiles> WithSourceRepository(
      const std::string& source_repository) const {
    return std::unique_ptr<Runfiles>(
        new Runfiles(handle_, source_repository, envvars_));
  }

 private:
  /// Takes ownership of @p handle.
  ///
  /// @param handle Handle from `rf_create`; freed with `rf_free`.
  /// @param source_repository Default source repository.
  /// @param envvars Value returned by #EnvVars.
  Runfiles(rf_runfiles* handle, std::string source_repository,
           std::vector<std::pair<std::string, std::string> > envvars)
      : handle_(handle, &rf_free),
        source_repository_(std::move(source_repository)),
        envvars_(std::move(envvars)) {}
  /// Shares @p handle with another instance.
  ///
  /// @param handle Handle shared with the instance this one derives from.
  /// @param source_repository Default source repository.
  /// @param envvars Value returned by #EnvVars.
  Runfiles(std::shared_ptr<rf_runfiles> handle, std::string source_repository,
           std::vector<std::pair<std::string, std::string> > envvars)
      : handle_(std::move(handle)),
        source_repository_(std::move(source_repository)),
        envvars_(std::move(envvars)) {}
  Runfiles(const Runfiles&) = delete;
  Runfiles(Runfiles&&) = delete;
  Runfiles& operator=(const Runfiles&) = delete;
  Runfiles& operator=(Runfiles&&) = delete;

  const std::shared_ptr<rf_runfiles> handle_;
  const std::string source_repository_;
  const std::vector<std::pair<std::string, std::string> > envvars_;
};

/// Exposed only for `runfiles_test.cc`; may change without notice.
namespace testing {

/// Computes the runfiles manifest and directory paths using the given
/// predicates in place of filesystem checks.
///
/// @param argv0 `argv[0]`, or `""` if unknown.
/// @param runfiles_manifest_file Candidate manifest path; may be `""`.
/// @param runfiles_dir Candidate directory; may be `""`.
/// @param is_runfiles_manifest Returns whether a path is a readable
///   manifest.
/// @param is_runfiles_directory Returns whether a path is a directory.
/// @param out_manifest Set to the manifest path found, or cleared.
/// @param out_directory Set to the directory found, or cleared.
/// @return `true` if at least one output was set.
bool TestOnly_PathsFrom(
    const std::string& argv0, std::string runfiles_manifest_file,
    std::string runfiles_dir,
    std::function<bool(const std::string&)> is_runfiles_manifest,
    std::function<bool(const std::string&)> is_runfiles_directory,
    std::string* out_manifest, std::string* out_directory);

/// @param path Path to test.
/// @return `true` if @p path is an absolute Unix or Windows path.
bool TestOnly_IsAbsolute(const std::string& path);

}  // namespace testing
}  // namespace runfiles
}  // namespace cc
}  // namespace rules_cc

#endif  // RULES_CC_CC_RUNFILES_RUNFILES_H_
