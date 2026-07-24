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
/// @brief Runfiles lookup library for Bazel-built C binaries and tests.
///
/// This is the pure-C counterpart to `//cc/runfiles:runfiles` (which is C++).
/// The two libraries implement the same algorithm and stay behavior-parity
/// (manifest parsing, `_repo_mapping` support, argv0/envvar path discovery,
/// prefix-match fallback, wildcard rewriting).
///
/// ### Usage
/// @code
///   #include "rules_cc/cc/runfiles/runfiles_c.h"
///
///   int main(int argc, char** argv) {
///     char err[256];
///     rf_runfiles* rf = rf_create(NULL, argv[0], err, sizeof(err));
///     if (!rf) { fputs(err, stderr); return 1; }
///
///     char path[4096];
///     int n = rf_rlocation(rf, "my_workspace/path/to/data.txt",
///                          path, sizeof(path));
///     if (n > 0) { /* path is the resolved runfile */ }
///
///     rf_free(rf);
///     return 0;
///   }
/// @endcode
///
/// ### Subprocesses
/// Iterate #rf_env_var from `0` to #rf_env_vars_count and set the returned
/// key/value pairs in the child's environment.
///
/// ### Custom allocator
/// Pass a #rf_allocator vtable as the first argument to any `rf_create*`
/// function to route all heap allocation through your own callbacks.
/// Pass `NULL` to use libc `malloc` / `realloc` / `free`. Each handle
/// remembers the allocator it was built with and always releases its
/// storage with the matching `free()` in #rf_free.
///
/// ### Sharing / lifetime
/// Each `rf_create*` call parses the manifest and `_repo_mapping` from
/// disk and returns a handle that fully owns its parsed state — no
/// process-wide cache, no refcount, no sharing across handles. Callers
/// that want to reuse the parse across scopes / threads / subsystems
/// should hold the returned #rf_runfiles* themselves (e.g. wrap it in a
/// `std::shared_ptr<rf_runfiles>` on the C++ side) rather than calling
/// `rf_create*` repeatedly.
///
/// ### Thread safety
/// The library carries no global state. Different handles are fully
/// independent and can be used concurrently from different threads
/// without synchronization. A single handle is safe for concurrent
/// #rf_rlocation / #rf_rlocation_from reads (the underlying data is
/// immutable after construction), but must NOT be freed concurrently
/// with any in-flight lookup. Same contract as `std::vector`: parallel
/// reads are fine, mixed reads + destruction is the caller's problem.

#ifndef RULES_CC_CC_RUNFILES_RUNFILES_C_H_
#define RULES_CC_CC_RUNFILES_RUNFILES_C_H_

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Opaque handle to a runfiles instance.
typedef struct rf_runfiles rf_runfiles;

/// Pluggable allocator vtable.
///
/// All three function pointers must be non-NULL if the vtable pointer
/// is non-NULL. `userdata` is passed unchanged as the first argument
/// to each call. `free(userdata, NULL)` must be a no-op.
typedef struct rf_allocator {
  /// `malloc(3)`-shaped allocation.
  void* (*malloc)(void* userdata, size_t size);
  /// `realloc(3)`-shaped resize; `ptr == NULL` means fresh allocation.
  void* (*realloc)(void* userdata, void* ptr, size_t size);
  /// `free(3)`-shaped release; must accept `NULL`.
  void (*free)(void* userdata, void* ptr);
  /// Opaque cookie forwarded to every call.
  void* userdata;
} rf_allocator;

/// Create a runfiles handle for a `cc_binary` or `cc_library`.
///
/// Uses `RUNFILES_MANIFEST_FILE` and `RUNFILES_DIR` from the
/// environment; falls back to `argv[0]`-based discovery if the env
/// vars are unset.
///
/// @param alloc Allocator vtable, or `NULL` for libc `malloc`/`free`.
///   The vtable is copied into the handle at construction so callers
///   may pass a short-lived (e.g. stack-local) vtable safely.
/// @param argv0 The program's `argv[0]`; pass `NULL` or `""` if unknown.
/// @param error_buf Optional buffer that receives a human-readable
///   error message on failure (NUL-terminated, truncated to
///   `error_buf_len`).
/// @param error_buf_len Size of @p error_buf in bytes.
/// @return New handle on success (release with #rf_free), or `NULL` on
///   error.
rf_runfiles* rf_create(const rf_allocator* alloc, const char* argv0,
                       char* error_buf, int error_buf_len);

/// Create a runfiles handle for a `cc_test`.
///
/// Uses `RUNFILES_MANIFEST_FILE` and `TEST_SRCDIR` from the
/// environment.
///
/// @param alloc Allocator vtable, or `NULL` for libc.
/// @param error_buf Optional error message buffer; see #rf_create.
/// @param error_buf_len Size of @p error_buf.
/// @return New handle, or `NULL` on error.
rf_runfiles* rf_create_for_test(const rf_allocator* alloc, char* error_buf,
                                int error_buf_len);

/// Extended constructor: pass explicit manifest / directory paths and a
/// default source repository. Any string may be `NULL` or `""` to skip
/// it (in which case discovery follows the same rules as #rf_create).
///
/// @param alloc Allocator vtable, or `NULL` for libc.
/// @param argv0 Program `argv[0]`, or `NULL`/`""` if unknown.
/// @param runfiles_manifest_file Explicit manifest path, or `""` to
///   defer to argv0 discovery.
/// @param runfiles_dir Explicit runfiles directory, or `""` to defer.
/// @param source_repository Default source repository (canonical name);
///   `""` denotes the main workspace.
/// @param error_buf Optional error buffer.
/// @param error_buf_len Size of @p error_buf.
/// @return New handle, or `NULL` on error.
rf_runfiles* rf_create_ex(const rf_allocator* alloc, const char* argv0,
                          const char* runfiles_manifest_file,
                          const char* runfiles_dir,
                          const char* source_repository, char* error_buf,
                          int error_buf_len);

/// Test variant of #rf_create_ex that reads paths from `TEST_SRCDIR` /
/// `RUNFILES_MANIFEST_FILE` but lets the caller pin the source repo.
///
/// @param alloc Allocator vtable, or `NULL` for libc.
/// @param source_repository Default source repository; `""` for main.
/// @param error_buf Optional error buffer.
/// @param error_buf_len Size of @p error_buf.
/// @return New handle, or `NULL` on error.
rf_runfiles* rf_create_for_test_ex(const rf_allocator* alloc,
                                   const char* source_repository,
                                   char* error_buf, int error_buf_len);

/// Resolve @p path (a runfiles-root-relative path) using the handle's
/// default source repository.
///
/// Rules (mirroring the C++ implementation):
///   - Absolute paths are returned as-is.
///   - Paths containing `".."`, `"./"`, `"/./"`, `"//"`, or trailing
///     `"/."` are rejected with `-1`. Backslash-separator variants of
///     the same patterns are also rejected.
///   - The first path component may be rewritten via `_repo_mapping`.
///   - Falls back to the runfiles directory if the manifest has no
///     match.
///
/// @param rf Runfiles handle.
/// @param path Runfiles-root-relative path to resolve.
/// @param result_buf Output buffer (NUL-terminated on success).
/// @param result_buf_len Size of @p result_buf.
/// @retval >0 Length of the resolved path (excluding NUL).
/// @retval 0 Path is well-formed but the runfile is unknown; @p
///   result_buf is set to `""`.
/// @retval -1 NULL argument, invalid path, or @p result_buf too small.
int rf_rlocation(const rf_runfiles* rf, const char* path, char* result_buf,
                 int result_buf_len);

/// Same as #rf_rlocation but overrides the source repository for this
/// call only.
///
/// @param rf Runfiles handle.
/// @param path Runfiles-root-relative path.
/// @param source_repository Source repo for `_repo_mapping` lookup;
///   `NULL` or `""` for the main workspace.
/// @param result_buf Output buffer.
/// @param result_buf_len Size of @p result_buf.
/// @return Same encoding as #rf_rlocation.
int rf_rlocation_from(const rf_runfiles* rf, const char* path,
                      const char* source_repository, char* result_buf,
                      int result_buf_len);

/// Number of environment variable pairs to publish to subprocesses.
///
/// Currently 3: `RUNFILES_MANIFEST_FILE`, `RUNFILES_DIR`,
/// `JAVA_RUNFILES`.
///
/// @param rf Runfiles handle.
/// @return Count, or 0 if @p rf is `NULL`.
int rf_env_vars_count(const rf_runfiles* rf);

/// Retrieve the @p index-th environment variable pair.
///
/// @param rf Runfiles handle.
/// @param index Zero-based index; must be `< rf_env_vars_count(rf)`.
/// @param key_buf Output buffer for the variable name (NUL-terminated).
/// @param key_buf_len Size of @p key_buf.
/// @param val_buf Output buffer for the value (NUL-terminated).
/// @param val_buf_len Size of @p val_buf.
/// @retval 1 Success.
/// @retval 0 Out-of-range index, NULL buffers, or a buffer too small.
int rf_env_var(const rf_runfiles* rf, int index, char* key_buf, int key_buf_len,
               char* val_buf, int val_buf_len);

/// Release a handle and free its parsed data.
///
/// No-op if @p rf is `NULL`. Uses the allocator that was remembered
/// when @p rf was built (the vtable copied in at #rf_create* time).
///
/// @param rf Handle to free.
void rf_free(rf_runfiles* rf);

/// Test whether @p path is absolute.
///
/// Recognises Unix leading `/` (but not UNC-style `//host/...`),
/// Windows drive-letter paths (e.g. `C:\foo`), and on Windows also
/// UNC paths (`\\server\share\...`). Never allocates.
///
/// @param path Path to test; may be `NULL`.
/// @retval 1 Absolute.
/// @retval 0 Relative, empty, or NULL.
int rf_is_absolute(const char* path);

#ifdef __cplusplus
}
#endif

#endif  // RULES_CC_CC_RUNFILES_RUNFILES_C_H_
