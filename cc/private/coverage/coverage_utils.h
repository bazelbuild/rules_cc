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

/// @file coverage_utils.h
/// @brief Helper toolkit consumed by @c collect_coverage.cc.
///
/// The helpers implement the low-level operations required to translate
/// per-test coverage data (either LLVM @c *.profraw or gcov @c *.gcda files)
/// into a unified coverage report. They mirror the individual shell functions
/// found in the historical @c collect_cc_coverage.sh script so that
/// @c collect_coverage.cc can remain a thin dispatcher.

#ifndef CC_PRIVATE_COVERAGE_COVERAGE_UTILS_H_
#define CC_PRIVATE_COVERAGE_COVERAGE_UTILS_H_

#include <filesystem>
#include <optional>
#include <string>

namespace bazel_coverage {

/// @brief Retrieve an environment variable if it is set and non-empty.
///
/// @param name The name of the environment variable.
/// @return The value of the variable, or @c std::nullopt if it is unset or
///         empty.
std::optional<std::string> GetEnv(const char* name);

/// @brief Retrieve a required environment variable, exiting the process on
///        failure with an explanatory message.
///
/// @param name The name of the environment variable.
/// @return The value of the variable.
std::string RequireEnv(const char* name);

/// @brief Enable or disable verbose logging of external commands.
///
/// When enabled, every subprocess invocation is echoed to standard error,
/// matching the behaviour of @c "set -x" in the historical shell script.
void SetVerbose(bool verbose);

/// @brief Check whether @p dir contains any @c *.profraw files.
///
/// Used to distinguish between the LLVM (Clang) coverage flow and the gcov
/// coverage flow.
///
/// @param dir The directory to scan.
/// @return True when at least one @c .profraw file exists.
bool UsesLlvm(const std::filesystem::path& dir);

/// @brief Compute code coverage using LLVM's @c llvm-profdata and @c llvm-cov.
///
/// Merges the per-test @c *.profraw files, then exports them as lcov data,
/// stripping the @c /proc/self/cwd/ prefix that Clang embeds when running
/// under Bazel's sandbox.
///
/// @param output_file Destination file for the lcov report.
/// @return Exit code (0 on success).
int LlvmCoverageLcov(const std::filesystem::path& output_file);

/// @brief Merge @c *.profraw files into a single @c .profdata output.
///
/// @param output_file Destination profdata path.
/// @return Exit code (0 on success).
int LlvmCoverageProfdata(const std::filesystem::path& output_file);

/// @brief Generate a gcov intermediate-format code coverage report.
///
/// Iterates the @c COVERAGE_MANIFEST looking for @c *.gcno files, copies each
/// one next to its matching @c .gcda file (gcov requires them to sit in the
/// same directory), and then invokes gcov once per pair. Depending on the
/// gcov version, output is emitted either as compressed JSON
/// (@c *.gcov.json.gz) which is moved next to @p output_file, or as textual
/// @c *.gcov files which are concatenated into @p output_file.
///
/// @param output_file Destination file for the assembled report.
/// @return Exit code (0 on success).
int GcovCoverage(const std::filesystem::path& output_file);

}  // namespace bazel_coverage

#endif  // CC_PRIVATE_COVERAGE_COVERAGE_UTILS_H_
