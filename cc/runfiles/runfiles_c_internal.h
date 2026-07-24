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

/// @file runfiles_c_internal.h
/// @brief Internal helpers of the runfiles C library.
///
/// These functions are shared between the C API in `runfiles_c.h` and
/// the C++ facade in `runfiles.cc` so both languages use the same
/// parsers, the same path-discovery logic, and the same validation
/// rules.
///
/// This header is NOT part of the public API. It is exposed only via
/// the `textual_hdrs` attribute of `//cc/runfiles:runfiles_c` so that
/// the C++ wrapper can `#include` it inside `extern "C" {}`.

#ifndef RULES_CC_CC_RUNFILES_RUNFILES_C_INTERNAL_H_
#define RULES_CC_CC_RUNFILES_RUNFILES_C_INTERNAL_H_

#include <stddef.h>
#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Result codes for streaming parser helpers.
typedef enum {
  RF_OK = 0,           ///< Success.
  RF_ERR_IO = 1,       ///< `fopen` / `read` failure.
  RF_ERR_FORMAT = 2,   ///< Malformed manifest / repo-mapping entry.
  RF_ERR_ALLOC = 3,    ///< Out of memory in the parser's scratch buffer.
  RF_ERR_CALLBACK = 4  ///< Callback returned non-zero to abort.
} rf_status;

/// Number of environment variable pairs both libraries publish to
/// subprocesses. The names live in #kRfEnvKeys below; the values are
/// per-handle (they encode the manifest / directory paths).
#define RF_NUM_ENV_VARS 3

/// Canonical order of the three env var names both libraries emit:
///   - `[0]` `RUNFILES_MANIFEST_FILE`
///   - `[1]` `RUNFILES_DIR`
///   - `[2]` `JAVA_RUNFILES` (compatibility shim for the Java launcher;
///     the TODO to remove it lives here so both languages see the same
///     intent).
///
/// Shared between `runfiles_c.c` and `runfiles.cc` so a change (e.g.
/// dropping `JAVA_RUNFILES`) happens in one place.
static const char* const kRfEnvKeys[RF_NUM_ENV_VARS] = {
    "RUNFILES_MANIFEST_FILE", "RUNFILES_DIR",
    // TODO(laszlocsomor): remove JAVA_RUNFILES once the Java launcher can
    // pick up RUNFILES_DIR.
    "JAVA_RUNFILES"};

// --------------------------------------------------------------------------
// Path / filesystem helpers (no allocation)
// --------------------------------------------------------------------------

/// Test whether @p path is absolute.
///
/// Recognises Unix leading `/` (but not UNC-style `//host/...`) and
/// Windows drive-letter paths. Drive-less absolute Windows paths like
/// `\foo` are NOT absolute. Matches `Runfiles::IsAbsolute`.
///
/// @param path Path to test.
/// @retval 1 Absolute.
/// @retval 0 Otherwise.
int rf_is_absolute(const char* path);

/// Test whether @p path is openable for reading.
/// @param path Filesystem path.
/// @retval 1 Openable.
/// @retval 0 Not openable.
int rf_is_readable_file(const char* path);

/// Test whether @p path names an existing directory.
/// @param path Filesystem path.
/// @retval 1 Directory.
/// @retval 0 Not a directory (or not present).
int rf_is_directory(const char* path);

/// Read an environment variable as a newly-allocated UTF-8 string.
///
/// On Windows uses `GetEnvironmentVariableW` so env vars published via
/// `SetEnvironmentVariable*` (which don't update the CRT `_environ`
/// block) are visible, and so non-ASCII values round-trip through
/// UTF-16. On POSIX defers to `getenv`. Caller frees with `free()`.
///
/// @param name ASCII env-var name.
/// @return Newly-allocated UTF-8 value, or `NULL` if unset / failure.
char* rf_getenv_alloc(const char* name);

/// `fopen` that accepts a UTF-8 @p path on all platforms.
///
/// On Windows converts @p path to UTF-16 and calls `_wfopen`. On POSIX
/// this is a direct `fopen`.
///
/// @param path UTF-8 file path.
/// @param mode `fopen` mode string (e.g. `"r"`).
/// @return `FILE*` on success, `NULL` on failure.
FILE* rf_fopen_utf8(const char* path, const char* mode);

/// Test whether @p path satisfies the Rlocation invariants.
///
/// Rejects empty paths, `../` and `./` prefixes, `/..`, `/./`, `//`,
/// and trailing `/.`.
///
/// @param path Path to validate.
/// @retval 1 Well-formed.
/// @retval 0 Rejected.
int rf_path_is_rlocation_valid(const char* path);

// --------------------------------------------------------------------------
// Unescape helper
// --------------------------------------------------------------------------

/// Unescape a manifest entry into @p out.
///
/// Recognised escapes: `\s -> ' '`, `\n -> '\n'`, `\b -> '\\'`. Any
/// other backslash sequence is passed through literally. Never
/// allocates.
///
/// @param in Source bytes (need not be NUL-terminated).
/// @param in_len Number of bytes to read from @p in.
/// @param out Destination buffer; must have space for `in_len + 1`
///   bytes. Written NUL-terminated.
/// @return Number of bytes written (excluding the trailing NUL).
size_t rf_unescape_into(const char* in, size_t in_len, char* out);

// --------------------------------------------------------------------------
// Path discovery
// --------------------------------------------------------------------------

/// Predicate signature for #rf_paths_from.
///
/// @param userdata Opaque cookie forwarded from the caller.
/// @param path Path to test.
/// @retval 1 True.
/// @retval 0 False.
typedef int (*rf_predicate)(void* userdata, const char* path);

/// Discover the runfiles manifest and/or directory.
///
/// Mirrors the C++ `PathsFrom` logic in `runfiles.cc`:
///   1. If @p argv0 is set and neither manifest nor directory is
///      already valid, try `argv0.runfiles/MANIFEST` +
///      `argv0.runfiles`, then `argv0.runfiles_manifest`.
///   2. If a directory was found but no manifest, try
///      `dir/MANIFEST` and `dir_manifest`.
///   3. If a manifest was found but no directory, try stripping the
///      `_manifest` / `/MANIFEST` suffix from the manifest path.
///
/// @param argv0 Program `argv[0]`, or `NULL`/`""` if unknown.
/// @param runfiles_manifest_file Env-provided manifest path (may be
///   `NULL` or `""`).
/// @param runfiles_dir Env-provided directory (may be `NULL` or `""`).
/// @param is_readable_file Predicate for existence checks; if `NULL`,
///   the built-in #rf_is_readable_file is used.
/// @param is_directory Predicate for directory checks; if `NULL`, the
///   built-in #rf_is_directory is used.
/// @param predicate_userdata Passed unchanged to both predicates.
/// @param out_manifest Output buffer for the resolved manifest path
///   (NUL-terminated, `""` if none found).
/// @param out_manifest_len Size of @p out_manifest.
/// @param out_directory Output buffer for the resolved directory path
///   (NUL-terminated, `""` if none found).
/// @param out_directory_len Size of @p out_directory.
/// @retval 1 At least one of {manifest, directory} was found.
/// @retval 0 Nothing found, or an output buffer is too small (in which
///   case both output buffers are left untouched).
int rf_paths_from(const char* argv0, const char* runfiles_manifest_file,
                  const char* runfiles_dir, rf_predicate is_readable_file,
                  rf_predicate is_directory, void* predicate_userdata,
                  char* out_manifest, size_t out_manifest_len,
                  char* out_directory, size_t out_directory_len);

// --------------------------------------------------------------------------
// Format helpers (no I/O, no allocation) shared by both languages' parsers
// --------------------------------------------------------------------------

/// Parse one manifest line. Never touches the filesystem, never
/// allocates.
///
/// The manifest line format is one of:
///   - `" escaped_key escaped_value"` — leading space; both fields
///     need #rf_unescape_into before use.
///   - `"raw_key raw_value"` — no escaping; key and value are the
///     literal bytes.
///
/// On success returns #RF_OK and writes byte offsets INTO @p line:
///   - `*key_off`, `*key_len` — the key span within @p line.
///   - `*val_off`, `*val_len` — the value span within @p line.
///   - `*needs_unescape` — `1` if the escaped form was used, else `0`.
///
/// @param line Line bytes (need not be NUL-terminated).
/// @param line_len Number of bytes in @p line.
/// @param line_index 1-based line number (used only in error text).
/// @param path_for_err Path label used in the error message; may be
///   `NULL` (rendered as `"?"`).
/// @param key_off Out: byte offset of the key.
/// @param key_len Out: byte length of the key.
/// @param val_off Out: byte offset of the value.
/// @param val_len Out: byte length of the value.
/// @param needs_unescape Out: `1` if escaped form, `0` if raw.
/// @param error_buf Optional buffer for a human-readable format error.
/// @param error_buf_len Size of @p error_buf.
/// @retval RF_OK Success.
/// @retval RF_ERR_FORMAT Malformed line.
rf_status rf_manifest_split_line(const char* line, size_t line_len,
                                 int line_index, const char* path_for_err,
                                 size_t* key_off, size_t* key_len,
                                 size_t* val_off, size_t* val_len,
                                 int* needs_unescape, char* error_buf,
                                 int error_buf_len);

/// Parse one repo-mapping line of the form
/// `"source,target_apparent,target"`.
///
/// Never touches the filesystem, never allocates. Writes byte offsets
/// into @p line on success.
///
/// @param line Line bytes.
/// @param line_len Number of bytes in @p line.
/// @param line_index 1-based line number (used only in error text).
/// @param path_for_err Path label used in the error message.
/// @param src_off Out: byte offset of the source-repo field.
/// @param src_len Out: byte length of the source-repo field.
/// @param ta_off Out: byte offset of the target-apparent field.
/// @param ta_len Out: byte length of the target-apparent field.
/// @param tgt_off Out: byte offset of the target field.
/// @param tgt_len Out: byte length of the target field.
/// @param error_buf Optional buffer for a human-readable format error.
/// @param error_buf_len Size of @p error_buf.
/// @retval RF_OK Success.
/// @retval RF_ERR_FORMAT Malformed line.
rf_status rf_repo_mapping_split_line(const char* line, size_t line_len,
                                     int line_index, const char* path_for_err,
                                     size_t* src_off, size_t* src_len,
                                     size_t* ta_off, size_t* ta_len,
                                     size_t* tgt_off, size_t* tgt_len,
                                     char* error_buf, int error_buf_len);

#ifdef __cplusplus
}
#endif

#endif  // RULES_CC_CC_RUNFILES_RUNFILES_C_INTERNAL_H_
