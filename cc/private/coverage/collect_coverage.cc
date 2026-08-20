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

/// @file collect_coverage.cc
/// @brief Entry point that collects code coverage data for C++ sources after
///        tests are executed.
///
/// This program is the native reimplementation of the historical
/// @c collect_cc_coverage.sh shell script that ships with Bazel. It runs on
/// Linux, macOS, and Windows. All non-trivial work is delegated to the
/// helpers in @c coverage_utils.h so that the dispatch logic here reads like
/// the shell script's @c main function.
///
/// The following environment variables are consumed:
///  - @c COVERAGE_DIR           Directory containing coverage metadata files.
///  - @c COVERAGE_MANIFEST      Location of the instrumented file manifest.
///  - @c COVERAGE_GCOV_PATH     Location of @c gcov (set by the TestRunner).
///  - @c COVERAGE_GCOV_OPTIONS  Additional options to pass to @c gcov.
///  - @c ROOT                   Directory from which coverage collection was
///                              invoked (contains @c .gcno files).
///  - @c VERBOSE_COVERAGE       Print debug information when non-empty.
///  - @c LLVM_PROFDATA          Path to @c llvm-profdata.
///  - @c LLVM_COV               Path to @c llvm-cov.
///  - @c GENERATE_LLVM_LCOV     When @c "1", emit lcov instead of profdata.
///  - @c BAZEL_CC_COVERAGE_TOOL The coverage tool to dispatch to. Defaults to
///                              @c GCOV; overridden to @c LLVM_LCOV or
///                              @c PROFDATA when @c *.profraw files are found.

#include <filesystem>
#include <iostream>
#include <string>

#include "cc/private/coverage/coverage_utils.h"

int main() {
  namespace fs = std::filesystem;
  using bazel_coverage::GcovCoverage;
  using bazel_coverage::GetEnv;
  using bazel_coverage::LlvmCoverageLcov;
  using bazel_coverage::LlvmCoverageProfdata;
  using bazel_coverage::RequireEnv;
  using bazel_coverage::SetVerbose;
  using bazel_coverage::UsesLlvm;

  SetVerbose(GetEnv("VERBOSE_COVERAGE").has_value());

  fs::path coverage_dir = RequireEnv("COVERAGE_DIR");

  // If LLVM coverage data is present, override the default GCOV tool with the
  // appropriate LLVM flow. Matches the shell script's `uses_llvm` branch.
  std::string tool = GetEnv("BAZEL_CC_COVERAGE_TOOL").value_or("GCOV");
  if (UsesLlvm(coverage_dir)) {
    tool = GetEnv("GENERATE_LLVM_LCOV").value_or("") == "1" ? "LLVM_LCOV"
                                                            : "PROFDATA";
  }

  if (tool == "GCOV") {
    return GcovCoverage(coverage_dir / "_cc_coverage.gcov");
  }
  if (tool == "PROFDATA") {
    return LlvmCoverageProfdata(coverage_dir / "_cc_coverage.profdata");
  }
  if (tool == "LLVM_LCOV") {
    return LlvmCoverageLcov(coverage_dir / "_cc_coverage.dat");
  }

  std::cerr << "Coverage tool " << tool << " not supported\n";
  return 1;
}
