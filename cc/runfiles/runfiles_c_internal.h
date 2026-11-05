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
/// @brief Helpers shared by runfiles_c.c and the C++ wrapper in
/// runfiles.cc. Not part of the public API.

#ifndef RULES_CC_CC_RUNFILES_RUNFILES_C_INTERNAL_H_
#define RULES_CC_CC_RUNFILES_RUNFILES_C_INTERNAL_H_

#include <stddef.h>
#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

struct rf_allocator;

/// Result of the parsing helpers.
typedef enum {
  RF_OK = 0,
  RF_ERR_IO = 1,       ///< Open or read failure.
  RF_ERR_FORMAT = 2,   ///< Malformed line.
  RF_ERR_ALLOC = 3,    ///< Allocation failure.
  RF_ERR_CALLBACK = 4  ///< An entry callback returned non-zero.
} rf_status;

/// Number of entries reported by rf_env_vars_count.
#define RF_NUM_ENV_VARS 3

/// @param path Path to test; may be `NULL`.
/// @return 1 if @p path is absolute, else 0. See runfiles_c.h.
int rf_is_absolute(const char* path);

/// @param path UTF-8 filesystem path.
/// @return 1 if @p path can be opened for reading, else 0.
int rf_is_readable_file(const char* path);

/// @param path UTF-8 filesystem path.
/// @return 1 if @p path is a directory, else 0.
int rf_is_directory(const char* path);

/// Reads an environment variable. On Windows the value is read with
/// GetEnvironmentVariableW and converted to UTF-8.
///
/// @param alloc Allocator for the result, or `NULL` for libc malloc.
/// @param name ASCII variable name.
/// @return Newly allocated value, freed by the caller with the matching
///   allocator, or `NULL` if the variable is unset or allocation fails.
char* rf_getenv_alloc(const struct rf_allocator* alloc, const char* name);

/// fopen that accepts a UTF-8 path on every platform.
///
/// @param path UTF-8 file path.
/// @param mode fopen mode string.
/// @return Open stream, or `NULL` on failure.
FILE* rf_fopen_utf8(const char* path, const char* mode);

/// @param path Path to validate; may be `NULL`.
/// @return 1 if @p path is acceptable to rf_rlocation: non-empty and free of
///   `..`, `./`, `//` and a trailing `/.` (with `/` or `\` as separator);
///   else 0.
int rf_path_is_rlocation_valid(const char* path);

/// Decodes manifest escapes: `\s` to space, `\n` to newline, `\b` to
/// backslash. Other sequences are copied unchanged.
///
/// @param in Source bytes; need not be NUL-terminated.
/// @param in_len Number of bytes to read from @p in.
/// @param out Destination of at least `in_len + 1` bytes; NUL-terminated on
///   return.
/// @return Number of bytes written, excluding the NUL.
size_t rf_unescape_into(const char* in, size_t in_len, char* out);

/// Filesystem check used by #rf_paths_from.
///
/// @param userdata The `predicate_userdata` given to #rf_paths_from.
/// @param path Path to test.
/// @return 1 if the check passes, else 0.
typedef int (*rf_predicate)(void* userdata, const char* path);

/// Locates the runfiles manifest and directory. Tries, in order: the given
/// paths; `<argv0>.runfiles/MANIFEST` with `<argv0>.runfiles`, then
/// `<argv0>.runfiles_manifest`; `<dir>/MANIFEST` and `<dir>_manifest` if only
/// the directory was found; the manifest path minus its `_manifest` or
/// `/MANIFEST` suffix if only the manifest was found.
///
/// @param argv0 `argv[0]`, or `NULL`/`""` if unknown.
/// @param runfiles_manifest_file Candidate manifest path; may be `NULL`/`""`.
/// @param runfiles_dir Candidate directory; may be `NULL`/`""`.
/// @param is_readable_file Manifest check, or `NULL` for
///   #rf_is_readable_file.
/// @param is_directory Directory check, or `NULL` for #rf_is_directory.
/// @param predicate_userdata Passed to both predicates.
/// @param alloc Allocator for the outputs, or `NULL` for libc malloc.
/// @param out_manifest Receives the manifest path, or `NULL` if not found.
///   Freed by the caller with @p alloc.
/// @param out_directory Receives the directory, or `NULL` if not found.
///   Freed by the caller with @p alloc.
/// @return 1 if at least one output was set; 0 if neither was found or
///   allocation failed, in which case both outputs are `NULL`.
int rf_paths_from(const char* argv0, const char* runfiles_manifest_file,
                  const char* runfiles_dir, rf_predicate is_readable_file,
                  rf_predicate is_directory, void* predicate_userdata,
                  const struct rf_allocator* alloc, char** out_manifest,
                  char** out_directory);

/// Splits one manifest line into key and value ranges. A line starting with
/// a space has escaped fields that need #rf_unescape_into.
///
/// @param line Line bytes without the newline; need not be NUL-terminated.
/// @param line_len Number of bytes in @p line.
/// @param line_index 1-based line number, for the error message.
/// @param path_for_err Manifest path for the error message; may be `NULL`.
/// @param key_off Receives the key's byte offset in @p line.
/// @param key_len Receives the key's byte length.
/// @param val_off Receives the value's byte offset in @p line.
/// @param val_len Receives the value's byte length.
/// @param needs_unescape Receives 1 if the fields are escaped, else 0.
/// @param error_buf Optional buffer for the error message.
/// @param error_buf_len Size of @p error_buf.
/// @return RF_OK, or RF_ERR_FORMAT if the line has no separator.
rf_status rf_manifest_split_line(const char* line, size_t line_len,
                                 int line_index, const char* path_for_err,
                                 size_t* key_off, size_t* key_len,
                                 size_t* val_off, size_t* val_len,
                                 int* needs_unescape, char* error_buf,
                                 int error_buf_len);

/// Splits one `_repo_mapping` line, `source,target_apparent,target`, into
/// field ranges.
///
/// @param line Line bytes without the newline; need not be NUL-terminated.
/// @param line_len Number of bytes in @p line.
/// @param line_index 1-based line number, for the error message.
/// @param path_for_err File path for the error message; may be `NULL`.
/// @param src_off Receives the source repository's byte offset in @p line.
/// @param src_len Receives the source repository's byte length.
/// @param ta_off Receives the apparent target name's byte offset.
/// @param ta_len Receives the apparent target name's byte length.
/// @param tgt_off Receives the canonical target name's byte offset.
/// @param tgt_len Receives the canonical target name's byte length.
/// @param error_buf Optional buffer for the error message.
/// @param error_buf_len Size of @p error_buf.
/// @return RF_OK, or RF_ERR_FORMAT if the line has fewer than two commas.
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
