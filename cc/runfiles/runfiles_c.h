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
/// This is the pure-C counterpart to `//cc/runfiles:runfiles` (which is
/// a thin C++ facade over this library). Both surfaces implement the
/// same algorithm and stay behavior-parity with the upstream Bazel C++
/// runfiles library (manifest parsing, `_repo_mapping` support,
/// argv0/envvar path discovery, prefix-match fallback, wildcard
/// rewriting).
///
/// ### Output contract
/// Variable-length outputs (resolved paths) use caller-provided buffers
/// with an snprintf-style "here's the size I needed" report. Callers
/// decide the grow-or-bail policy: use a stack buffer for the common
/// case, retry with the reported size on #RF_RLOCATION_BUF_TOO_SMALL,
/// or refuse to grow and error out. Env-var keys/values are returned
/// as pointers into static/handle-owned storage -- never freed by the
/// caller.
///
/// A future release may add an ergonomic alloc-out companion; the
/// caller-buffer form here is the low-level primitive both would share.
///
/// ### Usage
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
///       // buf is a NUL-terminated string, `needed` bytes long.
///     }
///     rf_free(rf);
///     return 0;
///   }
/// @endcode
///
/// ### Subprocesses
/// Iterate #rf_env_var_key and #rf_env_var_value from `0` to
/// #rf_env_vars_count and set the returned key/value pairs in the
/// child's environment.
///
/// ### Custom allocator
/// Pass a #rf_allocator vtable as the first argument to any `rf_create*`
/// function to route the library's internal allocations (parsed
/// manifest, `_repo_mapping` table, parser scratch, repo-mapping
/// concatenation scratch used in #rf_rlocation) through your own
/// callbacks. Pass `NULL` to use libc `malloc` / `realloc` / `free`.
/// Each handle remembers the allocator it was built with and always
/// releases its storage with the matching `free()` in #rf_free.
///
/// ### Sharing / lifetime
/// Each `rf_create*` call parses the manifest and `_repo_mapping` from
/// disk and returns a handle that fully owns its parsed state -- no
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
/// #rf_rlocation reads (the underlying data is immutable after
/// construction), but must NOT be freed concurrently with any in-flight
/// lookup. Same contract as `std::vector`: parallel reads are fine,
/// mixed reads + destruction is the caller's problem.

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

/// Result codes for #rf_rlocation.
typedef enum {
  /// Success; @p buf is NUL-terminated and @c *needed is `strlen(buf)`.
  RF_RLOCATION_OK = 0,
  /// Well-formed path but the runfile is unknown to this handle. @p buf
  /// is untouched and @c *needed is `0`.
  RF_RLOCATION_NOT_FOUND = 1,
  /// Path fails validation (empty, `..`-traversal, `//`, `/./`,
  /// trailing `/.`, or a `NULL` argument). @p buf is untouched.
  RF_RLOCATION_INVALID_PATH = 2,
  /// @p buf_cap is too small to hold the result. @p buf is untouched
  /// (no partial write) and @c *needed is the exact byte length the
  /// result would occupy (excluding the NUL terminator). Retry with a
  /// buffer of at least `*needed + 1` bytes.
  RF_RLOCATION_BUF_TOO_SMALL = 3,
  /// The handle's allocator failed while building an internal scratch
  /// key for `_repo_mapping` rewriting. Rare -- the scratch is bounded
  /// by the input path length plus the matched canonical name length --
  /// but surfaced explicitly so arena-backed callers can detect it.
  RF_RLOCATION_ALLOC_FAILED = 4,
} rf_rlocation_status;

/// Create a runfiles handle.
///
/// All string arguments are optional; passing `NULL` or `""` for
/// @p runfiles_manifest_file / @p runfiles_dir defers to argv0-based
/// discovery. @p source_repository is `""` for the main workspace.
///
/// Environment variables are NOT read by this function. Callers that
/// want automatic env discovery in production code should read
/// `RUNFILES_MANIFEST_FILE` and `RUNFILES_DIR` themselves and pass the
/// values here -- this keeps the library out of the process-env-reading
/// business and lets embedded consumers hand it whatever paths they've
/// resolved through their own configuration surface.
///
/// @param alloc Allocator vtable, or `NULL` for libc `malloc`/`free`.
///   The vtable is copied into the handle at construction so callers
///   may pass a short-lived (e.g. stack-local) vtable safely.
/// @param argv0 Program `argv[0]`, or `NULL`/`""` if unknown.
/// @param runfiles_manifest_file Explicit manifest path, or `NULL`/`""`
///   to defer to argv0 discovery.
/// @param runfiles_dir Explicit runfiles directory, or `NULL`/`""` to
///   defer.
/// @param source_repository Default source repository (canonical name);
///   `""` denotes the main workspace.
/// @param err_buf Optional buffer that receives a human-readable error
///   message on failure (NUL-terminated, truncated to @p err_buf_len).
/// @param err_buf_len Size of @p err_buf in bytes.
/// @return New handle on success (release with #rf_free), or `NULL` on
///   error.
rf_runfiles* rf_create(const rf_allocator* alloc, const char* argv0,
                       const char* runfiles_manifest_file,
                       const char* runfiles_dir, const char* source_repository,
                       char* err_buf, size_t err_buf_len);

/// Create a runfiles handle from `RUNFILES_MANIFEST_FILE` and
/// `TEST_SRCDIR` -- the environment variables Bazel sets for `cc_test`
/// binaries.
///
/// This is the sole entry point that reads process environment
/// variables. Production code should route env-reading through the
/// caller and pass results into #rf_create.
///
/// @param alloc Allocator vtable, or `NULL` for libc.
/// @param source_repository Default source repository; `""` for main.
/// @param err_buf Optional error buffer.
/// @param err_buf_len Size of @p err_buf.
/// @return New handle, or `NULL` on error.
rf_runfiles* rf_create_for_test(const rf_allocator* alloc,
                                const char* source_repository, char* err_buf,
                                size_t err_buf_len);

/// Release a handle and free its parsed data.
///
/// No-op if @p rf is `NULL`. Uses the allocator that was remembered
/// when @p rf was built (the vtable copied in at #rf_create* time).
///
/// @param rf Handle to free.
void rf_free(rf_runfiles* rf);

/// Resolve @p path (a runfiles-root-relative path) to a filesystem
/// path, writing the result into @p buf.
///
/// Snprintf-style contract: @c *needed is always set on the two data
/// statuses (#RF_RLOCATION_OK and #RF_RLOCATION_BUF_TOO_SMALL) so a
/// caller can grow-and-retry exactly once with the reported size, or
/// bail out on a hard budget. @p buf is left untouched on
/// #RF_RLOCATION_BUF_TOO_SMALL (no partial write).
///
/// @c buf may be `NULL` and @c buf_cap `0` -- this reduces the call to
/// a pure size query, returning #RF_RLOCATION_BUF_TOO_SMALL with the
/// required size in @c *needed. Useful for consumers that want to
/// allocate exactly-sized storage before the fill call.
///
/// Rules (mirroring the upstream C++ implementation):
///   - Absolute paths are returned as-is.
///   - Paths containing `".."`, `"./"`, `"/./"`, `"//"`, or trailing
///     `"/."` are rejected as #RF_RLOCATION_INVALID_PATH. Backslash-
///     separator variants of the same patterns are also rejected.
///   - The first path component may be rewritten via `_repo_mapping`.
///   - Falls back to the runfiles directory if the manifest has no
///     match.
///
/// @param rf Runfiles handle.
/// @param path Runfiles-root-relative path.
/// @param source_repository Source repo for `_repo_mapping` lookup.
///   `NULL` selects the handle's default source repository. Pass `""`
///   to explicitly override with the main workspace.
/// @param buf Caller-owned output buffer, or `NULL` for a size query.
///   Written NUL-terminated on #RF_RLOCATION_OK; untouched otherwise.
/// @param buf_cap Size of @p buf in bytes.
/// @param needed Out-only. Set on #RF_RLOCATION_OK and
///   #RF_RLOCATION_BUF_TOO_SMALL to the byte length the result would
///   occupy (excluding the NUL). Set to `0` on the other statuses.
///   May be `NULL` if the caller has no interest in the size hint.
/// @return See #rf_rlocation_status.
rf_rlocation_status rf_rlocation(rf_runfiles* rf, const char* path,
                                 const char* source_repository, char* buf,
                                 size_t buf_cap, size_t* needed);

/// Number of environment variable pairs to publish to subprocesses.
///
/// Currently `3`: `RUNFILES_MANIFEST_FILE`, `RUNFILES_DIR`,
/// `JAVA_RUNFILES`.
int rf_env_vars_count(void);

/// Static name of the @p index-th env var to publish.
///
/// @param index Zero-based index; must be `< rf_env_vars_count()`.
/// @return Pointer into static storage -- do NOT free. Returns `NULL`
///   if @p index is out of range.
const char* rf_env_var_key(int index);

/// Value of the @p index-th env var for this handle.
///
/// The returned pointer aliases handle-owned storage -- valid until
/// #rf_free is called on @p rf, and must NOT be freed. May be the
/// empty string (e.g. `RUNFILES_DIR` is `""` in manifest-only mode).
///
/// @param rf Runfiles handle.
/// @param index Zero-based index; must be `< rf_env_vars_count()`.
/// @return Handle-owned NUL-terminated string, or `NULL` if @p index
///   is out of range or @p rf is `NULL`.
const char* rf_env_var_value(rf_runfiles* rf, int index);

/// Test whether @p path is absolute.
///
/// Recognises Unix leading `/` (but not UNC-style `//host/...`) and
/// Windows drive-letter paths. Never allocates.
///
/// @param path Path to test; may be `NULL`.
/// @retval 1 Absolute.
/// @retval 0 Relative, empty, or `NULL`.
int rf_is_absolute(const char* path);

#ifdef __cplusplus
}
#endif

#endif  // RULES_CC_CC_RUNFILES_RUNFILES_C_H_
