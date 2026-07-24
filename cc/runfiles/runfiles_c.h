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

/// @file runfiles_c.h
/// @brief Runfiles lookup for Bazel-built C binaries and tests.
///
/// @code
///   #include "rules_cc/cc/runfiles/runfiles_c.h"
///
///   int main(int argc, char** argv) {
///     char err[256];
///     rf_runfiles* rf = rf_create(NULL, argv[0], NULL, NULL, "",
///                                 err, sizeof(err));
///     if (!rf) { fputs(err, stderr); return 1; }
///
///     char buf[4096];
///     size_t needed = 0;
///     if (rf_rlocation(rf, "my_workspace/path/to/data.txt", NULL,
///                      buf, sizeof(buf), &needed) == RF_RLOCATION_OK) {
///       // buf holds the NUL-terminated path.
///     }
///     rf_free(rf);
///     return 0;
///   }
/// @endcode
///
/// Handles are independent and own their parsed state. A handle may be
/// read concurrently from several threads, but must not be freed while a
/// lookup is in flight.

#ifndef RULES_CC_CC_RUNFILES_RUNFILES_C_H_
#define RULES_CC_CC_RUNFILES_RUNFILES_C_H_

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Opaque runfiles handle.
typedef struct rf_runfiles rf_runfiles;

/// Allocator for a handle's internal allocations. All three function
/// pointers must be non-NULL.
typedef struct rf_allocator {
  /// @param userdata The struct's `userdata` field.
  /// @param size Bytes to allocate.
  /// @return New allocation, or `NULL` on failure.
  void* (*malloc)(void* userdata, size_t size);
  /// @param userdata The struct's `userdata` field.
  /// @param ptr Existing allocation, or `NULL`.
  /// @param size New size in bytes.
  /// @return Resized allocation, or `NULL` on failure (leaving @p ptr valid).
  void* (*realloc)(void* userdata, void* ptr, size_t size);
  /// @param userdata The struct's `userdata` field.
  /// @param ptr Allocation to release; must accept `NULL`.
  void (*free)(void* userdata, void* ptr);
  /// Passed unchanged as the first argument of every call.
  void* userdata;
} rf_allocator;

/// Result of #rf_rlocation.
typedef enum {
  /// `buf` holds the NUL-terminated result and `*needed` is its length.
  RF_RLOCATION_OK = 0,
  /// The path is well-formed but unknown to this handle. `buf` is untouched.
  RF_RLOCATION_NOT_FOUND = 1,
  /// The path is `NULL`, empty, or contains `..`, `./`, `//`, or a trailing
  /// `/.` (with `/` or `\` as separator). `buf` is untouched.
  RF_RLOCATION_INVALID_PATH = 2,
  /// `buf_cap` is smaller than `*needed + 1`. `buf` is untouched.
  RF_RLOCATION_BUF_TOO_SMALL = 3,
  /// The handle's allocator failed while applying a `_repo_mapping` rewrite.
  RF_RLOCATION_ALLOC_FAILED = 4,
} rf_rlocation_status;

/// Creates a handle. Does not read environment variables.
///
/// @param alloc Allocator, or `NULL` for libc. The struct is copied; only
///   `userdata` must outlive the handle.
/// @param argv0 `argv[0]`, or `NULL`/`""` if unknown.
/// @param runfiles_manifest_file Manifest path, or `NULL`/`""` to derive it
///   from @p runfiles_dir or @p argv0.
/// @param runfiles_dir Runfiles directory, or `NULL`/`""` to derive it from
///   @p runfiles_manifest_file or @p argv0.
/// @param source_repository Canonical name of the default source
///   repository; `""` is the main repository.
/// @param err_buf Optional buffer for a NUL-terminated error message.
/// @param err_buf_len Size of @p err_buf.
/// @return Handle to release with #rf_free, or `NULL` on error.
rf_runfiles* rf_create(const rf_allocator* alloc, const char* argv0,
                       const char* runfiles_manifest_file,
                       const char* runfiles_dir, const char* source_repository,
                       char* err_buf, size_t err_buf_len);

/// Creates a handle from `RUNFILES_MANIFEST_FILE` and `TEST_SRCDIR`, the
/// environment variables Bazel sets for `cc_test`.
///
/// @param alloc Allocator, or `NULL` for libc. See #rf_create.
/// @param source_repository Canonical name of the default source
///   repository; `""` is the main repository.
/// @param err_buf Optional buffer for a NUL-terminated error message.
/// @param err_buf_len Size of @p err_buf.
/// @return Handle to release with #rf_free, or `NULL` on error.
rf_runfiles* rf_create_for_test(const rf_allocator* alloc,
                                const char* source_repository, char* err_buf,
                                size_t err_buf_len);

/// Frees a handle and everything it owns.
///
/// @param rf Handle from #rf_create or #rf_create_for_test, or `NULL` for a
///   no-op.
void rf_free(rf_runfiles* rf);

/// Resolves a runfiles-root-relative path.
///
/// Absolute paths are returned unchanged. Otherwise the first path
/// component is rewritten through `_repo_mapping` for the source
/// repository, and the result is looked up in the manifest (exact match,
/// then longest directory prefix) and finally joined to the runfiles
/// directory if there is one.
///
/// @param rf Handle to look up in.
/// @param path Runfiles-root-relative path.
/// @param source_repository Overrides the handle's default. `NULL` uses the
///   default; `""` is the main repository.
/// @param buf Receives the NUL-terminated result on #RF_RLOCATION_OK. May be
///   `NULL` with @p buf_cap `0` to query the required size.
/// @param buf_cap Size of @p buf.
/// @param needed Optional. Set to the result length (excluding the NUL) on
///   #RF_RLOCATION_OK and #RF_RLOCATION_BUF_TOO_SMALL, and to `0` otherwise.
/// @return See #rf_rlocation_status.
rf_rlocation_status rf_rlocation(rf_runfiles* rf, const char* path,
                                 const char* source_repository, char* buf,
                                 size_t buf_cap, size_t* needed);

/// @return Number of environment variables a subprocess needs in order to
///   find the same runfiles; the valid index range for #rf_env_var_key and
///   #rf_env_var_value.
int rf_env_vars_count(void);

/// @param index Zero-based index below #rf_env_vars_count.
/// @return Name of the variable, in static storage, or `NULL` if @p index
///   is out of range.
const char* rf_env_var_key(int index);

/// @param rf Handle whose paths to report.
/// @param index Zero-based index below #rf_env_vars_count.
/// @return Value of the variable, owned by @p rf and valid until #rf_free;
///   may be `""`. `NULL` if @p index is out of range or @p rf is `NULL`.
const char* rf_env_var_value(rf_runfiles* rf, int index);

/// @param path Path to test; may be `NULL`.
/// @return 1 if @p path starts with a single `/`, or with a drive letter
///   followed by `:/` or `:\`; 0 otherwise, including for `NULL`.
int rf_is_absolute(const char* path);

#ifdef __cplusplus
}
#endif

#endif  // RULES_CC_CC_RUNFILES_RUNFILES_C_H_
