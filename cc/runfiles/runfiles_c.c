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

#include "runfiles_c.h"

#include <errno.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "runfiles_c_internal.h"

#ifdef _WIN32
#include <windows.h>
#else
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#endif

#define RF_LINE_INITIAL 8192
#define RF_MANIFEST_INITIAL_CAPACITY 256
#define RF_REPO_MAP_INITIAL_CAPACITY 32

// ==========================================================================
// Libc-backed default allocator.
//
// Used when a caller passes NULL for the allocator to rf_create*. The
// function pointers are static wrappers so the vtable dispatch has one
// shape everywhere and no code path needs to branch on "is this the
// default?".
// ==========================================================================

static void* rf_libc_malloc(void* ud, size_t n) {
  (void)ud;
  return malloc(n);
}
static void* rf_libc_realloc(void* ud, void* p, size_t n) {
  (void)ud;
  return realloc(p, n);
}
static void rf_libc_free(void* ud, void* p) {
  (void)ud;
  free(p);
}
static const rf_allocator g_libc_allocator = {rf_libc_malloc, rf_libc_realloc,
                                              rf_libc_free, NULL};

// ==========================================================================
// Allocator helpers — one vtable dispatch, no default-vs-custom branch.
// ==========================================================================

static void* rf_a_malloc(const rf_allocator* a, size_t n) {
  return a->malloc(a->userdata, n);
}
static void* rf_a_realloc(const rf_allocator* a, void* p, size_t n) {
  return a->realloc(a->userdata, p, n);
}
static void rf_a_free(const rf_allocator* a, void* p) {
  a->free(a->userdata, p);
}

static char* rf_a_strdup(const rf_allocator* a, const char* s) {
  if (!s) return NULL;
  size_t len = strlen(s);
  char* copy = (char*)rf_a_malloc(a, len + 1);
  if (copy) memcpy(copy, s, len + 1);
  return copy;
}

static char* rf_a_strdupn(const rf_allocator* a, const char* s, size_t len) {
  char* copy = (char*)rf_a_malloc(a, len + 1);
  if (copy) {
    if (len) memcpy(copy, s, len);
    copy[len] = '\0';
  }
  return copy;
}

// ==========================================================================
// Windows Unicode helpers
//
// On Windows, all filesystem and env-var access is done through W-variant
// Win32 APIs so that non-ASCII paths and env values (which would otherwise
// be mangled by the process ANSI code page) work correctly. Runfiles paths
// and env-var values are treated as UTF-8 at the library boundary.
//
// The two conversion helpers use a caller-provided stack buffer first and
// only fall back to `malloc` when the stack buffer is too small — this
// keeps the hot path (short paths, short env-var values) allocation-free.
// They intentionally bypass the pluggable rf_allocator: the buffers are
// transient (freed immediately after the Win32 call) and never observed
// by callers.
// ==========================================================================

#ifdef _WIN32
// Convert @p utf8 to UTF-16. Writes into @p stack_buf when the result
// fits in @p stack_cap wchars; otherwise mallocs a fresh buffer. Caller
// must `if (result != stack_buf) free(result);` after use. Returns NULL
// on invalid UTF-8 or allocation failure.
static wchar_t* rf_utf8_to_wide(const char* utf8, wchar_t* stack_buf,
                                size_t stack_cap) {
  if (!utf8) return NULL;
  int n = MultiByteToWideChar(CP_UTF8, 0, utf8, -1, NULL, 0);
  if (n <= 0) return NULL;
  wchar_t* w = ((size_t)n <= stack_cap)
                   ? stack_buf
                   : (wchar_t*)malloc((size_t)n * sizeof(wchar_t));
  if (!w) return NULL;
  if (MultiByteToWideChar(CP_UTF8, 0, utf8, -1, w, n) <= 0) {
    if (w != stack_buf) free(w);
    return NULL;
  }
  return w;
}

// Convert @p wide to UTF-8 with the same stack-first / heap-fallback
// contract as rf_utf8_to_wide.
static char* rf_wide_to_utf8(const wchar_t* wide, char* stack_buf,
                             size_t stack_cap) {
  if (!wide) return NULL;
  int n = WideCharToMultiByte(CP_UTF8, 0, wide, -1, NULL, 0, NULL, NULL);
  if (n <= 0) return NULL;
  char* s = ((size_t)n <= stack_cap) ? stack_buf : (char*)malloc((size_t)n);
  if (!s) return NULL;
  if (WideCharToMultiByte(CP_UTF8, 0, wide, -1, s, n, NULL, NULL) <= 0) {
    if (s != stack_buf) free(s);
    return NULL;
  }
  return s;
}
#endif  // _WIN32

// ==========================================================================
// rf_fopen_utf8 — cross-platform fopen accepting UTF-8 paths.
//
// Windows: converts the path to UTF-16 and calls _wfopen. POSIX: plain
// fopen (paths are already UTF-8 there). Single home for the wide-char
// open dance so every filesystem call site is one line.
// ==========================================================================

FILE* rf_fopen_utf8(const char* path, const char* mode) {
#ifdef _WIN32
  wchar_t stack_path[1024];
  wchar_t stack_mode[16];
  wchar_t* wpath =
      rf_utf8_to_wide(path, stack_path, sizeof(stack_path) / sizeof(wchar_t));
  if (!wpath) return NULL;
  wchar_t* wmode =
      rf_utf8_to_wide(mode, stack_mode, sizeof(stack_mode) / sizeof(wchar_t));
  FILE* f = wmode ? _wfopen(wpath, wmode) : NULL;
  if (wpath != stack_path) free(wpath);
  if (wmode && wmode != stack_mode) free(wmode);
  return f;
#else
  return fopen(path, mode);
#endif
}

// ==========================================================================
// Path / filesystem helpers (no allocation)
// ==========================================================================

int rf_is_absolute(const char* path) {
  if (!path || !path[0]) return 0;
  char c = path[0];
  // Unix-style absolute: leading '/' that is NOT a UNC-style "//host".
  if (c == '/') return path[1] != '/';
  // Windows drive-letter absolute: "<letter>:\..." or "<letter>:/...".
  if (((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')) && path[1] == ':' &&
      (path[2] == '\\' || path[2] == '/'))
    return 1;
#ifdef _WIN32
  // Windows UNC path: "\\server\share\..." (also "\\?\..." device
  // namespace prefix). POSIX systems don't have UNC, so this branch is
  // Windows-only — matches the existing test that pins "//host/share"
  // to non-absolute on all platforms.
  if (c == '\\' && path[1] == '\\') return 1;
#endif
  return 0;
}

int rf_is_readable_file(const char* path) {
  FILE* f = rf_fopen_utf8(path, "r");
  if (f) {
    fclose(f);
    return 1;
  }
  return 0;
}

int rf_is_directory(const char* path) {
#ifdef _WIN32
  wchar_t stack[1024];
  wchar_t* wpath =
      rf_utf8_to_wide(path, stack, sizeof(stack) / sizeof(wchar_t));
  if (!wpath) return 0;  // OOM or bad UTF-8: treat as not-a-directory
  DWORD attrs = GetFileAttributesW(wpath);
  if (wpath != stack) free(wpath);
  return (attrs != INVALID_FILE_ATTRIBUTES) &&
         (attrs & FILE_ATTRIBUTE_DIRECTORY);
#else
  struct stat buf;
  return stat(path, &buf) == 0 && S_ISDIR(buf.st_mode);
#endif
}

// Read an env-var as a newly-allocated UTF-8 string. Caller frees with
// `free()`. Returns NULL if unset. Used by the rf_create* entry points
// so Windows sees env vars set via SetEnvironmentVariableW (not visible
// through the CRT `_environ` block) and so non-ASCII values round-trip
// through UTF-16. Also called from the C++ facade (see runfiles.cc's
// GetEnv) so the Windows-Unicode env-var dance lives in one place.
char* rf_getenv_alloc(const char* name) {
#ifdef _WIN32
  // Env-var names are always short ASCII (e.g. "RUNFILES_MANIFEST_FILE",
  // "TEST_SRCDIR"), so ASCII → UTF-16 is a straight widening copy — no
  // MultiByteToWideChar call, no allocation.
  wchar_t wname[128];
  size_t i;
  for (i = 0; name[i] && i < sizeof(wname) / sizeof(wchar_t) - 1; i++) {
    wname[i] = (wchar_t)(unsigned char)name[i];
  }
  if (name[i]) return NULL;  // name too long for our stack buffer
  wname[i] = L'\0';

  DWORD wsize = GetEnvironmentVariableW(wname, NULL, 0);
  if (wsize == 0) return NULL;

  wchar_t stack_val[1024];
  wchar_t* wval = ((size_t)wsize <= sizeof(stack_val) / sizeof(wchar_t))
                      ? stack_val
                      : (wchar_t*)malloc((size_t)wsize * sizeof(wchar_t));
  if (!wval) return NULL;
  DWORD written = GetEnvironmentVariableW(wname, wval, wsize);
  if (written == 0 || written >= wsize) {
    if (wval != stack_val) free(wval);
    return NULL;
  }
  // rf_wide_to_utf8 with a NULL stack buffer forces heap allocation, so
  // the returned pointer is always caller-owned (never stack).
  char* out = rf_wide_to_utf8(wval, NULL, 0);
  if (wval != stack_val) free(wval);
  return out;
#else
  const char* v = getenv(name);
  if (!v) return NULL;
  size_t len = strlen(v);
  char* copy = (char*)malloc(len + 1);
  if (!copy) return NULL;
  memcpy(copy, v, len + 1);
  return copy;
#endif
}

int rf_path_is_rlocation_valid(const char* path) {
  if (!path || !path[0]) return 0;
  size_t len = strlen(path);
  // Treat both '/' and '\' as separators for the traversal checks.
  // Bazel manifests use forward slashes, so a backslash in a caller-
  // supplied rlocation key is suspicious on any platform; rejecting
  // unconditionally closes the Windows path-traversal hole (e.g.
  // "..\\..\\etc\\passwd") without needing a platform ifdef.
#define RF_IS_SEP(c) ((c) == '/' || (c) == '\\')
  // starts with "../" or "..\\"
  if (len >= 3 && path[0] == '.' && path[1] == '.' && RF_IS_SEP(path[2]))
    return 0;
  // starts with "./" or ".\\"
  if (len >= 2 && path[0] == '.' && RF_IS_SEP(path[1])) return 0;
  // ends with "/." or "\\."
  if (len >= 2 && RF_IS_SEP(path[len - 2]) && path[len - 1] == '.') return 0;
  // contains "/..", "/./", or "//" (and their backslash variants)
  for (size_t i = 0; i + 1 < len; i++) {
    if (RF_IS_SEP(path[i])) {
      if (RF_IS_SEP(path[i + 1])) return 0;
      if (i + 2 < len && path[i + 1] == '.' && path[i + 2] == '.') return 0;
      if (i + 2 < len && path[i + 1] == '.' && RF_IS_SEP(path[i + 2])) return 0;
    }
  }
#undef RF_IS_SEP
  return 1;
}

// ==========================================================================
// Unescape
// ==========================================================================

size_t rf_unescape_into(const char* in, size_t in_len, char* out) {
  size_t j = 0;
  for (size_t i = 0; i < in_len; ++i) {
    if (in[i] == '\\' && i + 1 < in_len) {
      switch (in[i + 1]) {
        case 's':
          out[j++] = ' ';
          ++i;
          break;
        case 'n':
          out[j++] = '\n';
          ++i;
          break;
        case 'b':
          out[j++] = '\\';
          ++i;
          break;
        default:
          out[j++] = in[i];
          out[j++] = in[i + 1];
          ++i;
          break;
      }
    } else {
      out[j++] = in[i];
    }
  }
  out[j] = '\0';
  return j;
}

// ==========================================================================
// PathsFrom
// ==========================================================================

// Suffix appended to argv0 to discover the runfiles manifest inside a
// runfiles directory.
static const char kRunfilesSlashManifest[] = ".runfiles/MANIFEST";
static const char kRunfilesDir[] = ".runfiles";
static const char kRunfilesManifest[] = ".runfiles_manifest";
static const char kSlashManifest[] = "/MANIFEST";
static const char kUnderscoreManifest[] = "_manifest";

// Concatenate a and b into out. Returns 1 on success, 0 if the buffer
// is too small.
static int rf_join2(const char* a, const char* b, char* out, size_t out_len) {
  size_t la = strlen(a);
  size_t lb = strlen(b);
  if (la + lb + 1 > out_len) return 0;
  memcpy(out, a, la);
  memcpy(out + la, b, lb);
  out[la + lb] = '\0';
  return 1;
}

// Invoke a caller-provided predicate if non-NULL, else the built-in
// rf_is_readable_file / rf_is_directory. Keeps the rf_paths_from body
// free of null-check boilerplate.
#define RF_IS_FILE(path)                                           \
  (is_readable_file ? is_readable_file(predicate_userdata, (path)) \
                    : rf_is_readable_file(path))
#define RF_IS_DIR(path)                                    \
  (is_directory ? is_directory(predicate_userdata, (path)) \
                : rf_is_directory(path))

int rf_paths_from(const char* argv0, const char* runfiles_manifest_file,
                  const char* runfiles_dir, rf_predicate is_readable_file,
                  rf_predicate is_directory, void* predicate_userdata,
                  char* out_manifest, size_t out_manifest_len,
                  char* out_directory, size_t out_directory_len) {
  if (!out_manifest || out_manifest_len == 0 || !out_directory ||
      out_directory_len == 0)
    return 0;

  // Copy inputs into local buffers we can rewrite while searching.
  // Empty ("") indicates "not set / not yet discovered".
  char mf_buf[4096];
  char dir_buf[4096];

  const char* mf_in = runfiles_manifest_file ? runfiles_manifest_file : "";
  const char* dir_in = runfiles_dir ? runfiles_dir : "";

  if (strlen(mf_in) + 1 > sizeof(mf_buf)) return 0;
  if (strlen(dir_in) + 1 > sizeof(dir_buf)) return 0;

  strcpy(mf_buf, mf_in);
  strcpy(dir_buf, dir_in);

  int mf_valid = mf_buf[0] && RF_IS_FILE(mf_buf);
  int dir_valid = dir_buf[0] && RF_IS_DIR(dir_buf);

  if (argv0 && argv0[0] && !mf_valid && !dir_valid) {
    // argv0.runfiles/MANIFEST + argv0.runfiles
    if (!rf_join2(argv0, kRunfilesSlashManifest, mf_buf, sizeof(mf_buf)))
      return 0;
    if (!rf_join2(argv0, kRunfilesDir, dir_buf, sizeof(dir_buf))) return 0;
    mf_valid = RF_IS_FILE(mf_buf);
    dir_valid = RF_IS_DIR(dir_buf);
    if (!mf_valid) {
      if (!rf_join2(argv0, kRunfilesManifest, mf_buf, sizeof(mf_buf))) return 0;
      mf_valid = RF_IS_FILE(mf_buf);
    }
  }

  if (!mf_valid && !dir_valid) return 0;

  if (!mf_valid) {
    // Try dir + "/MANIFEST" then dir + "_manifest".
    if (!rf_join2(dir_buf, kSlashManifest, mf_buf, sizeof(mf_buf))) return 0;
    mf_valid = RF_IS_FILE(mf_buf);
    if (!mf_valid) {
      if (!rf_join2(dir_buf, kUnderscoreManifest, mf_buf, sizeof(mf_buf)))
        return 0;
      mf_valid = RF_IS_FILE(mf_buf);
    }
  }

  if (!dir_valid) {
    // If mf ends with ".runfiles_manifest" or "/MANIFEST", derive the
    // directory by stripping the 9-char suffix ("_manifest" or
    // "/MANIFEST"). Each suffix check must guard against mf being
    // shorter than the suffix itself to avoid reading before mf_buf.
    size_t mf_len = strlen(mf_buf);
    const size_t kStripLen = 9;
    const size_t kRunfilesManifestLen = sizeof(kRunfilesManifest) - 1;
    const size_t kSlashManifestLen = sizeof(kSlashManifest) - 1;
    int matches =
        (mf_len >= kRunfilesManifestLen &&
         strcmp(mf_buf + mf_len - kRunfilesManifestLen, kRunfilesManifest) ==
             0) ||
        (mf_len >= kSlashManifestLen &&
         strcmp(mf_buf + mf_len - kSlashManifestLen, kSlashManifest) == 0);
    if (matches) {
      if (mf_len - kStripLen + 1 > sizeof(dir_buf)) return 0;
      memcpy(dir_buf, mf_buf, mf_len - kStripLen);
      dir_buf[mf_len - kStripLen] = '\0';
      dir_valid = RF_IS_DIR(dir_buf);
    }
  }

  if (mf_valid) {
    size_t l = strlen(mf_buf);
    if (l + 1 > out_manifest_len) return 0;
    memcpy(out_manifest, mf_buf, l + 1);
  } else {
    out_manifest[0] = '\0';
  }

  if (dir_valid) {
    size_t l = strlen(dir_buf);
    if (l + 1 > out_directory_len) return 0;
    memcpy(out_directory, dir_buf, l + 1);
  } else {
    out_directory[0] = '\0';
  }

  return 1;
}
#undef RF_IS_FILE
#undef RF_IS_DIR

// ==========================================================================
// Streaming line reader
// ==========================================================================

/// Read a single line from @p f into `*line_buf`, growing it as
/// needed via the pluggable allocator. Strips trailing `\n` and `\r`.
///
/// Reads one byte at a time via `getc_unlocked` (POSIX) / `_getc_nolock`
/// (MSVC) so embedded NUL bytes are preserved verbatim (an `fgets`+`strlen`
/// shape would silently truncate any line containing a `\0`). Using the
/// unlocked getc variant skips the per-call FILE lock that `fgetc` takes
/// — safe here because the FILE* is a function-local resource never
/// shared across threads.
///
/// @param f Open input stream.
/// @param line_buf In/out: growing heap buffer. May start as `NULL`
///   with `*line_cap == 0`.
/// @param line_cap In/out: current capacity of `*line_buf`.
/// @param a Allocator used for grow-a-buffer operations.
/// @retval >=0 Line length written to `*line_buf`.
/// @retval -1 EOF with nothing read.
/// @retval -2 I/O error.
/// @retval -3 Allocation failure.
static int rf_read_line(FILE* f, char** line_buf, size_t* line_cap,
                        const rf_allocator* a) {
#ifdef _WIN32
#define RF_GETC(fp) _getc_nolock(fp)
#else
#define RF_GETC(fp) getc_unlocked(fp)
#endif
  size_t used = 0;
  for (;;) {
    // Need room for one more byte plus a NUL terminator.
    if (used + 2 >= *line_cap) {
      size_t new_cap = *line_cap ? *line_cap * 2 : RF_LINE_INITIAL;
      char* np = (char*)rf_a_realloc(a, *line_buf, new_cap);
      if (!np) return -3;
      *line_buf = np;
      *line_cap = new_cap;
    }
    int ch = RF_GETC(f);
    if (ch == EOF) {
      if (ferror(f)) return -2;
      if (used == 0) return -1;
      break;
    }
    (*line_buf)[used++] = (char)ch;
    if (ch == '\n') break;
  }
  (*line_buf)[used] = '\0';
  while (used > 0 &&
         ((*line_buf)[used - 1] == '\n' || (*line_buf)[used - 1] == '\r')) {
    (*line_buf)[--used] = '\0';
  }
  return (int)used;
#undef RF_GETC
}

// ==========================================================================
// Format helpers (pure — no I/O, no allocation). Shared by the C-side
// streaming parsers below AND by the C++ facade in runfiles.cc.
// ==========================================================================

rf_status rf_manifest_split_line(const char* line, size_t line_len,
                                 int line_index, const char* path_for_err,
                                 size_t* key_off, size_t* key_len,
                                 size_t* val_off, size_t* val_len,
                                 int* needs_unescape, char* error_buf,
                                 int error_buf_len) {
  // " escaped_key escaped_value"  -> needs_unescape=1
  // "raw_key raw_value"           -> needs_unescape=0
  int escaped = (line_len > 0 && line[0] == ' ');
  size_t head_off = escaped ? 1 : 0;
  const char* head = line + head_off;
  size_t head_len = line_len - head_off;
  const char* space = (const char*)memchr(head, ' ', head_len);
  if (!space) {
    if (error_buf && error_buf_len > 0)
      snprintf(
          error_buf, error_buf_len,
          "ERROR: bad runfiles manifest entry in \"%s\" line #%d: \"%.*s\"",
          path_for_err ? path_for_err : "?", line_index, (int)line_len, line);
    return RF_ERR_FORMAT;
  }
  *key_off = head_off;
  *key_len = (size_t)(space - head);
  *val_off = head_off + *key_len + 1;
  *val_len = line_len - *val_off;
  *needs_unescape = escaped;
  return RF_OK;
}

rf_status rf_repo_mapping_split_line(const char* line, size_t line_len,
                                     int line_index, const char* path_for_err,
                                     size_t* src_off, size_t* src_len,
                                     size_t* ta_off, size_t* ta_len,
                                     size_t* tgt_off, size_t* tgt_len,
                                     char* error_buf, int error_buf_len) {
  const char* first = (const char*)memchr(line, ',', line_len);
  const char* second = NULL;
  if (first) {
    size_t after_first = (size_t)(first - line) + 1;
    second =
        (const char*)memchr(line + after_first, ',', line_len - after_first);
  }
  if (!first || !second) {
    if (error_buf && error_buf_len > 0)
      snprintf(
          error_buf, error_buf_len,
          "ERROR: bad repository mapping entry in \"%s\" line #%d: \"%.*s\"",
          path_for_err ? path_for_err : "?", line_index, (int)line_len, line);
    return RF_ERR_FORMAT;
  }
  *src_off = 0;
  *src_len = (size_t)(first - line);
  *ta_off = *src_len + 1;
  *ta_len = (size_t)(second - (first + 1));
  *tgt_off = *ta_off + *ta_len + 1;
  *tgt_len = line_len - *tgt_off;
  return RF_OK;
}

// ==========================================================================
// Manifest parser (streaming, C-private). Used by rf_data_build only —
// the C++ facade has its own FILE*-based parser and does NOT call this.
// ==========================================================================

static rf_status rf_parse_manifest_into(
    const char* path,
    int (*on_entry)(void* userdata, const char* key, size_t key_len,
                    const char* value, size_t value_len),
    void* userdata, char* error_buf, int error_buf_len, const rf_allocator* a) {
  FILE* f = rf_fopen_utf8(path, "r");
  if (!f) {
    if (error_buf && error_buf_len > 0)
      snprintf(error_buf, error_buf_len,
               "ERROR: cannot open runfiles manifest \"%s\"", path);
    return RF_ERR_IO;
  }

  char* line = NULL;
  size_t line_cap = 0;
  char* scratch = NULL;  // buffer for unescaped key/value
  size_t scratch_cap = 0;
  rf_status status = RF_OK;
  int line_count = 0;

  for (;;) {
    int len = rf_read_line(f, &line, &line_cap, a);
    if (len == -1) break;
    if (len == -2) {
      if (error_buf && error_buf_len > 0)
        snprintf(error_buf, error_buf_len,
                 "ERROR: I/O error reading manifest \"%s\"", path);
      status = RF_ERR_IO;
      break;
    }
    if (len == -3) {
      status = RF_ERR_ALLOC;
      break;
    }
    line_count++;
    // Match the original C++ implementation: a blank line terminates
    // parsing (Bazel-emitted manifests never contain them).
    if (len == 0) break;

    size_t key_off, key_len, val_off, val_len;
    int needs_unescape;
    status = rf_manifest_split_line(line, (size_t)len, line_count, path,
                                    &key_off, &key_len, &val_off, &val_len,
                                    &needs_unescape, error_buf, error_buf_len);
    if (status != RF_OK) break;

    int abort;
    if (needs_unescape) {
      size_t need = key_len + 1 + val_len + 1;
      if (need > scratch_cap) {
        char* np = (char*)rf_a_realloc(a, scratch, need);
        if (!np) {
          status = RF_ERR_ALLOC;
          break;
        }
        scratch = np;
        scratch_cap = need;
      }
      size_t kn = rf_unescape_into(line + key_off, key_len, scratch);
      size_t vn = rf_unescape_into(line + val_off, val_len, scratch + kn + 1);
      abort = on_entry(userdata, scratch, kn, scratch + kn + 1, vn);
    } else {
      abort =
          on_entry(userdata, line + key_off, key_len, line + val_off, val_len);
    }
    if (abort != 0) {
      status = RF_ERR_CALLBACK;
      break;
    }
  }

  rf_a_free(a, scratch);
  rf_a_free(a, line);
  fclose(f);
  return status;
}

// ==========================================================================
// Repo-mapping parser (streaming, C-private).
// ==========================================================================

static rf_status rf_parse_repo_mapping_into(
    const char* path,
    int (*on_entry)(void* userdata, const char* target_apparent,
                    size_t target_apparent_len, const char* source,
                    size_t source_len, const char* target, size_t target_len),
    void* userdata, char* error_buf, int error_buf_len, const rf_allocator* a) {
  FILE* f = rf_fopen_utf8(path, "r");
  if (!f) return RF_OK;  // matches C++ silent-skip semantics

  char* line = NULL;
  size_t line_cap = 0;
  rf_status status = RF_OK;
  int line_count = 0;

  for (;;) {
    int len = rf_read_line(f, &line, &line_cap, a);
    if (len == -1) break;
    if (len == -2) {
      if (error_buf && error_buf_len > 0)
        snprintf(error_buf, error_buf_len,
                 "ERROR: I/O error reading repo mapping \"%s\"", path);
      status = RF_ERR_IO;
      break;
    }
    if (len == -3) {
      status = RF_ERR_ALLOC;
      break;
    }
    line_count++;
    // Match the original C++ implementation: a blank line terminates
    // parsing (Bazel-emitted manifests never contain them).
    if (len == 0) break;

    size_t src_off, src_len, ta_off, ta_len, tgt_off, tgt_len;
    status = rf_repo_mapping_split_line(
        line, (size_t)len, line_count, path, &src_off, &src_len, &ta_off,
        &ta_len, &tgt_off, &tgt_len, error_buf, error_buf_len);
    if (status != RF_OK) break;

    if (on_entry(userdata, line + ta_off, ta_len, line + src_off, src_len,
                 line + tgt_off, tgt_len) != 0) {
      status = RF_ERR_CALLBACK;
      break;
    }
  }

  rf_a_free(a, line);
  fclose(f);
  return status;
}

// ==========================================================================
// rf_runfiles — parsed state owned by exactly one handle.
//
// No refcount, no sharing across handles, no locking. Each rf_create*
// produces a fresh handle; rf_free releases everything it owns.
// ==========================================================================

/// One repo-mapping row. Sorted lexicographically by
/// `(target_apparent, source_repo)` — reproduces
/// `std::pair<string,string>::operator<` exactly, including
/// "'*' sorts before every valid repo-name char" for wildcard entries.
typedef struct {
  char* target_apparent;
  size_t ta_len;
  char* source_repo;  ///< May end in `*` for wildcard entries.
  size_t sr_len;
  char* value;
  size_t value_len;
} rf_repo_entry;

/// One manifest row. `key_len` is cached so binary search doesn't need
/// to `strlen` the stored key on every probe.
typedef struct {
  char* key;
  size_t key_len;
  char* value;
} rf_manifest_entry;

struct rf_runfiles {
  /// Owned copy of the allocator vtable this handle was built with.
  /// Copying the struct in — rather than storing a pointer — lets
  /// callers pass a short-lived (e.g. stack-local) #rf_allocator to
  /// #rf_create_ex; the handle uses this copy for its whole lifetime.
  rf_allocator alloc;

  char* directory;          ///< Resolved runfiles directory (or `""`).
  char* manifest_file;      ///< Resolved manifest file (or `""`).
  char* source_repository;  ///< Default source repo for #rf_rlocation.

  rf_manifest_entry* manifest;  ///< Sorted manifest rows.
  size_t manifest_count;
  size_t manifest_capacity;

  rf_repo_entry* repo_map;  ///< Sorted `_repo_mapping` rows.
  size_t repo_map_count;
  size_t repo_map_capacity;

  // Env-var values are not stored: rf_env_var derives them from
  // manifest_file / directory above.
};

// ==========================================================================
// Sorting parallel arrays (manifest and repo-mapping)
// ==========================================================================

static int rf_manifest_qsort_cmp(const void* a, const void* b) {
  const rf_manifest_entry* ea = (const rf_manifest_entry*)a;
  const rf_manifest_entry* eb = (const rf_manifest_entry*)b;
  return strcmp(ea->key, eb->key);
}

// Compare two (target_apparent, source_repo) pairs lexicographically —
// reproduces std::pair<string,string>::operator< exactly, including
// "'*' sorts before every valid repo-name char" for wildcard entries.
// Used both for sorting the repo-map and for binary-searching a lookup
// key against a stored entry.
static int rf_repo_key_cmp(const char* ta_a, size_t ta_a_len, const char* sr_a,
                           size_t sr_a_len, const char* ta_b, size_t ta_b_len,
                           const char* sr_b, size_t sr_b_len) {
  size_t nt = ta_a_len < ta_b_len ? ta_a_len : ta_b_len;
  int cmp = nt ? memcmp(ta_a, ta_b, nt) : 0;
  if (cmp != 0) return cmp;
  if (ta_a_len != ta_b_len) return ta_a_len < ta_b_len ? -1 : 1;

  size_t ns = sr_a_len < sr_b_len ? sr_a_len : sr_b_len;
  cmp = ns ? memcmp(sr_a, sr_b, ns) : 0;
  if (cmp != 0) return cmp;
  if (sr_a_len != sr_b_len) return sr_a_len < sr_b_len ? -1 : 1;
  return 0;
}

static int rf_repo_qsort_cmp(const void* a, const void* b) {
  const rf_repo_entry* ea = (const rf_repo_entry*)a;
  const rf_repo_entry* eb = (const rf_repo_entry*)b;
  return rf_repo_key_cmp(ea->target_apparent, ea->ta_len, ea->source_repo,
                         ea->sr_len, eb->target_apparent, eb->ta_len,
                         eb->source_repo, eb->sr_len);
}

// ==========================================================================
// Callbacks for populating rf_runfiles
//
// A callback that returns non-zero surfaces as RF_ERR_CALLBACK from the
// parser and the whole build path unwinds. Returning non-zero on OOM
// therefore doubles as error propagation — no separate flag needed.
// ==========================================================================

static int rf_build_manifest_cb(void* userdata, const char* key, size_t klen,
                                const char* value, size_t vlen) {
  rf_runfiles* rf = (rf_runfiles*)userdata;
  const rf_allocator* a = &rf->alloc;

  if (rf->manifest_count >= rf->manifest_capacity) {
    size_t nc = rf->manifest_capacity ? rf->manifest_capacity * 2
                                      : RF_MANIFEST_INITIAL_CAPACITY;
    rf_manifest_entry* nr = (rf_manifest_entry*)rf_a_realloc(
        a, rf->manifest, sizeof(rf_manifest_entry) * nc);
    if (!nr) return 1;
    rf->manifest = nr;
    rf->manifest_capacity = nc;
  }
  char* kk = rf_a_strdupn(a, key, klen);
  char* vv = rf_a_strdupn(a, value, vlen);
  if (!kk || !vv) {
    rf_a_free(a, kk);
    rf_a_free(a, vv);
    return 1;
  }
  rf_manifest_entry* e = &rf->manifest[rf->manifest_count++];
  e->key = kk;
  e->key_len = klen;
  e->value = vv;
  return 0;
}

static int rf_build_repo_map_cb(void* userdata, const char* ta, size_t ta_len,
                                const char* src, size_t src_len,
                                const char* tgt, size_t tgt_len) {
  rf_runfiles* rf = (rf_runfiles*)userdata;
  const rf_allocator* a = &rf->alloc;

  if (rf->repo_map_count >= rf->repo_map_capacity) {
    size_t nc = rf->repo_map_capacity ? rf->repo_map_capacity * 2
                                      : RF_REPO_MAP_INITIAL_CAPACITY;
    rf_repo_entry* nr = (rf_repo_entry*)rf_a_realloc(
        a, rf->repo_map, sizeof(rf_repo_entry) * nc);
    if (!nr) return 1;
    rf->repo_map = nr;
    rf->repo_map_capacity = nc;
  }

  char* ta_copy = rf_a_strdupn(a, ta, ta_len);
  char* sr_copy = rf_a_strdupn(a, src, src_len);
  char* vv = rf_a_strdupn(a, tgt, tgt_len);
  if (!ta_copy || !sr_copy || !vv) {
    rf_a_free(a, ta_copy);
    rf_a_free(a, sr_copy);
    rf_a_free(a, vv);
    return 1;
  }

  rf_repo_entry* e = &rf->repo_map[rf->repo_map_count++];
  e->target_apparent = ta_copy;
  e->ta_len = ta_len;
  e->source_repo = sr_copy;
  e->sr_len = src_len;
  e->value = vv;
  e->value_len = tgt_len;
  return 0;
}

// ==========================================================================
// RlocationUnchecked (data-level; no repo mapping / validation)
// ==========================================================================

/// Binary search on the manifest for a key equal to the first
/// @p prefix_len bytes of @p path. Does NOT mutate @p path. Passing
/// `strlen(path)` as @p prefix_len yields an exact-key search.
///
/// @return Matching index, or `-1` if no match.
static int rf_bsearch_manifest_prefix(const rf_runfiles* rf, const char* path,
                                      size_t prefix_len) {
  int lo = 0, hi = (int)rf->manifest_count - 1;
  while (lo <= hi) {
    int mid = lo + (hi - lo) / 2;
    const rf_manifest_entry* e = &rf->manifest[mid];
    size_t n = e->key_len < prefix_len ? e->key_len : prefix_len;
    int cmp = n ? memcmp(e->key, path, n) : 0;
    if (cmp == 0)
      cmp = (e->key_len < prefix_len) ? -1 : (e->key_len > prefix_len) ? 1 : 0;
    if (cmp == 0) return mid;
    if (cmp < 0)
      lo = mid + 1;
    else
      hi = mid - 1;
  }
  return -1;
}

// Resolve `path` against the manifest/directory only (no repo mapping,
// no path validation, no absolute-path passthrough). Returns positive
// length on success, 0 if not found, -1 on buffer-too-small.
static int rf_rlocation_unchecked(const rf_runfiles* rf, const char* path,
                                  char* out, int out_len) {
  size_t path_len = strlen(path);
  // 1) Exact match (prefix search with the full path length).
  int idx = rf_bsearch_manifest_prefix(rf, path, path_len);
  if (idx >= 0) {
    const char* v = rf->manifest[idx].value;
    int vlen = (int)strlen(v);
    if (vlen + 1 > out_len) return -1;
    memcpy(out, v, vlen + 1);
    return vlen;
  }
  // 2) Longest-prefix match.
  if (rf->manifest_count > 0) {
    size_t prefix_end = path_len;
    while (prefix_end > 0) {
      size_t i = prefix_end;
      while (i > 0 && path[i - 1] != '/') i--;
      if (i == 0) break;
      prefix_end = i - 1;

      int pidx = rf_bsearch_manifest_prefix(rf, path, prefix_end);
      if (pidx >= 0) {
        const char* v = rf->manifest[pidx].value;
        int vlen = (int)strlen(v);
        size_t rem_len = path_len - prefix_end - 1;
        int total = vlen + 1 + (int)rem_len;
        if (total + 1 > out_len) return -1;
        memcpy(out, v, vlen);
        out[vlen] = '/';
        memcpy(out + vlen + 1, path + prefix_end + 1, rem_len);
        out[total] = '\0';
        return total;
      }
    }
  }
  // 3) Directory fallback.
  if (rf->directory && rf->directory[0]) {
    int dlen = (int)strlen(rf->directory);
    int total = dlen + 1 + (int)path_len;
    if (total + 1 > out_len) return -1;
    memcpy(out, rf->directory, dlen);
    out[dlen] = '/';
    memcpy(out + dlen + 1, path, path_len + 1);
    return total;
  }
  return 0;
}

// Helper: rlocation from a virtually-concatenated `prefix + suffix` key.
// Used after a repo-mapping rewrite so the caller can pass "canonical +
// path.substr(first_slash)" without doing the join themselves.
static int rf_rlocation_unchecked_join(const rf_runfiles* rf,
                                       const char* prefix, size_t prefix_len,
                                       const char* suffix, size_t suffix_len,
                                       char* out, int out_len) {
  size_t total = prefix_len + suffix_len;
  char stack_buf[8192];
  char* tmp;
  int use_heap = 0;
  if (total + 1 <= sizeof(stack_buf)) {
    tmp = stack_buf;
  } else {
    tmp = (char*)rf_a_malloc(&rf->alloc, total + 1);
    if (!tmp) return -1;
    use_heap = 1;
  }
  memcpy(tmp, prefix, prefix_len);
  if (suffix_len) memcpy(tmp + prefix_len, suffix, suffix_len);
  tmp[total] = '\0';
  int r = rf_rlocation_unchecked(rf, tmp, out, out_len);
  if (use_heap) rf_a_free(&rf->alloc, tmp);
  return r;
}

// ==========================================================================
// Public C API — construction
// ==========================================================================

// Free every allocation reachable from @p rf, then @p rf itself. Used
// both by rf_free and by the mid-construction error paths in
// rf_create_ex.
static void rf_free_impl(rf_runfiles* rf) {
  if (!rf) return;
  // Snapshot the vtable so rf_a_free can still dispatch after `rf`
  // itself is freed at the end.
  rf_allocator a = rf->alloc;
  rf_a_free(&a, rf->directory);
  rf_a_free(&a, rf->manifest_file);
  rf_a_free(&a, rf->source_repository);
  for (size_t i = 0; i < rf->manifest_count; i++) {
    rf_a_free(&a, rf->manifest[i].key);
    rf_a_free(&a, rf->manifest[i].value);
  }
  rf_a_free(&a, rf->manifest);
  for (size_t i = 0; i < rf->repo_map_count; i++) {
    rf_a_free(&a, rf->repo_map[i].target_apparent);
    rf_a_free(&a, rf->repo_map[i].source_repo);
    rf_a_free(&a, rf->repo_map[i].value);
  }
  rf_a_free(&a, rf->repo_map);
  rf_a_free(&a, rf);
}

rf_runfiles* rf_create_ex(const rf_allocator* alloc, const char* argv0,
                          const char* manifest, const char* dir,
                          const char* source_repo, char* err, int err_len) {
  if (!alloc) alloc = &g_libc_allocator;

  char resolved_manifest[4096];
  char resolved_directory[4096];
  if (!rf_paths_from(argv0 ? argv0 : "", manifest, dir, NULL, NULL, NULL,
                     resolved_manifest, sizeof(resolved_manifest),
                     resolved_directory, sizeof(resolved_directory))) {
    if (err && err_len > 0) {
      snprintf(err, err_len, "ERROR: cannot find runfiles (argv0=\"%s\")",
               argv0 ? argv0 : "");
    }
    return NULL;
  }

  rf_runfiles* rf = (rf_runfiles*)rf_a_malloc(alloc, sizeof(rf_runfiles));
  if (!rf) return NULL;
  memset(rf, 0, sizeof(*rf));
  rf->alloc = *alloc;  // owned copy — safe against short-lived vtables

  rf->directory = rf_a_strdup(alloc, resolved_directory);
  rf->manifest_file = rf_a_strdup(alloc, resolved_manifest);
  rf->source_repository = rf_a_strdup(alloc, source_repo ? source_repo : "");
  if (!rf->directory || !rf->manifest_file || !rf->source_repository) {
    rf_free_impl(rf);
    return NULL;
  }

  if (resolved_manifest[0]) {
    rf_status s = rf_parse_manifest_into(
        resolved_manifest, rf_build_manifest_cb, rf, err, err_len, alloc);
    if (s != RF_OK) {
      rf_free_impl(rf);
      return NULL;
    }
    if (rf->manifest_count > 1)
      qsort(rf->manifest, rf->manifest_count, sizeof(rf_manifest_entry),
            rf_manifest_qsort_cmp);
  }

  // Resolve the _repo_mapping path against the just-parsed manifest.
  // Grow from an 8 KB stack buffer up to 1 MB before giving up
  // (silently, matching C++'s "no repo mapping file" branch).
  {
    char stack_buf[8192];
    char* heap_buf = NULL;
    char* buf = stack_buf;
    size_t cap = sizeof(stack_buf);
    int n = rf_rlocation_unchecked(rf, "_repo_mapping", buf, (int)cap);
    while (n == -1 && cap < (1u << 20)) {
      cap *= 2;
      char* np = (char*)rf_a_realloc(alloc, heap_buf, cap);
      if (!np) {
        rf_a_free(alloc, heap_buf);
        rf_free_impl(rf);
        return NULL;
      }
      heap_buf = np;
      buf = heap_buf;
      n = rf_rlocation_unchecked(rf, "_repo_mapping", buf, (int)cap);
    }
    if (n > 0) {
      rf_status s = rf_parse_repo_mapping_into(buf, rf_build_repo_map_cb, rf,
                                               err, err_len, alloc);
      if (s != RF_OK) {
        rf_a_free(alloc, heap_buf);
        rf_free_impl(rf);
        return NULL;
      }
      if (rf->repo_map_count > 1)
        qsort(rf->repo_map, rf->repo_map_count, sizeof(rf_repo_entry),
              rf_repo_qsort_cmp);
    }
    rf_a_free(alloc, heap_buf);
  }

  return rf;
}

// Shared body of the three env-reading rf_create* entry points. Reads
// RUNFILES_MANIFEST_FILE and @p dir_env_key from the environment (via
// rf_getenv_alloc, so Windows Unicode env vars work) and forwards to
// rf_create_ex.
static rf_runfiles* rf_create_from_env(const rf_allocator* alloc,
                                       const char* argv0,
                                       const char* dir_env_key,
                                       const char* source_repo, char* err,
                                       int err_len) {
  char* mf = rf_getenv_alloc("RUNFILES_MANIFEST_FILE");
  char* dir = rf_getenv_alloc(dir_env_key);
  rf_runfiles* r = rf_create_ex(alloc, argv0, mf ? mf : "", dir ? dir : "",
                                source_repo, err, err_len);
  free(mf);
  free(dir);
  return r;
}

rf_runfiles* rf_create(const rf_allocator* alloc, const char* argv0, char* err,
                       int err_len) {
  return rf_create_from_env(alloc, argv0, "RUNFILES_DIR", "", err, err_len);
}

rf_runfiles* rf_create_for_test(const rf_allocator* alloc, char* err,
                                int err_len) {
  return rf_create_from_env(alloc, "", "TEST_SRCDIR", "", err, err_len);
}

rf_runfiles* rf_create_for_test_ex(const rf_allocator* alloc,
                                   const char* source_repo, char* err,
                                   int err_len) {
  return rf_create_from_env(alloc, "", "TEST_SRCDIR", source_repo, err,
                            err_len);
}

// ==========================================================================
// Rlocation (with repo-mapping)
// ==========================================================================

// Return < 0, == 0, > 0 comparing an entry to a lookup key
// (target_apparent, source_repo). Thin wrapper over rf_repo_key_cmp
// so sort and lookup share the same lex-order definition.
static int rf_cmp_lookup_key(const rf_repo_entry* e,
                             const char* target_apparent, size_t ta_len,
                             const char* source_repo, size_t sr_len) {
  return rf_repo_key_cmp(e->target_apparent, e->ta_len, e->source_repo,
                         e->sr_len, target_apparent, ta_len, source_repo,
                         sr_len);
}

// Find upper_bound(key): index of first repo-map entry strictly greater
// than (target_apparent, source_repo). Returns repo_map_count if none.
static size_t rf_rm_upper_bound(const rf_runfiles* rf,
                                const char* target_apparent, size_t ta_len,
                                const char* source_repo, size_t sr_len) {
  size_t lo = 0, hi = rf->repo_map_count;
  while (lo < hi) {
    size_t mid = lo + (hi - lo) / 2;
    int cmp = rf_cmp_lookup_key(&rf->repo_map[mid], target_apparent, ta_len,
                                source_repo, sr_len);
    if (cmp <= 0)
      lo = mid + 1;
    else
      hi = mid;
  }
  return lo;
}

int rf_rlocation_from(const rf_runfiles* rf, const char* path,
                      const char* source_repository, char* result_buf,
                      int result_buf_len) {
  if (!rf || !path || !result_buf || result_buf_len <= 0) return -1;
  result_buf[0] = '\0';

  if (!rf_path_is_rlocation_valid(path)) return -1;

  if (rf_is_absolute(path)) {
    int plen = (int)strlen(path);
    if (plen + 1 > result_buf_len) return -1;
    memcpy(result_buf, path, plen + 1);
    return plen;
  }

  const char* sr = source_repository ? source_repository : "";
  size_t sr_len = strlen(sr);

  const char* slash = strchr(path, '/');
  if (!slash) {
    // No repo prefix — resolve directly.
    return rf_rlocation_unchecked(rf, path, result_buf, result_buf_len);
  }

  size_t first_slash = (size_t)(slash - path);
  if (rf->repo_map_count == 0) {
    return rf_rlocation_unchecked(rf, path, result_buf, result_buf_len);
  }

  size_t ub = rf_rm_upper_bound(rf, path, first_slash, sr, sr_len);
  // Matches C++ std::prev(begin()) semantic: when upper_bound sits at
  // begin(), floor stays at begin() and we still inspect the first
  // entry — it may be a wildcard whose target_apparent matches ours,
  // in which case rewriting must still fire even though the entry
  // sorts strictly greater than the lookup key.
  size_t floor = (ub == 0) ? 0 : ub - 1;
  const rf_repo_entry* e = &rf->repo_map[floor];
  int cmp = rf_cmp_lookup_key(e, path, first_slash, sr, sr_len);
  const char* suffix = path + first_slash;
  size_t suffix_len = strlen(suffix);
  // Exact match, OR wildcard: entry's target_apparent equals the
  // lookup's, entry's source_repo ends in '*', and lookup's source_repo
  // starts with the prefix (source_repo before the '*').
  int wildcard_match = e->ta_len == first_slash &&
                       memcmp(e->target_apparent, path, first_slash) == 0 &&
                       e->sr_len > 0 && e->source_repo[e->sr_len - 1] == '*' &&
                       e->sr_len - 1 <= sr_len &&
                       memcmp(e->source_repo, sr, e->sr_len - 1) == 0;
  if (cmp == 0 || wildcard_match) {
    return rf_rlocation_unchecked_join(rf, e->value, e->value_len, suffix,
                                       suffix_len, result_buf, result_buf_len);
  }

  return rf_rlocation_unchecked(rf, path, result_buf, result_buf_len);
}

int rf_rlocation(const rf_runfiles* rf, const char* path, char* result_buf,
                 int result_buf_len) {
  if (!rf) return -1;
  return rf_rlocation_from(rf, path, rf->source_repository, result_buf,
                           result_buf_len);
}

// ==========================================================================
// Envvars
// ==========================================================================

int rf_env_vars_count(const rf_runfiles* rf) {
  if (!rf) return 0;
  return RF_NUM_ENV_VARS;
}

int rf_env_var(const rf_runfiles* rf, int index, char* key_buf, int key_buf_len,
               char* val_buf, int val_buf_len) {
  if (!rf || index < 0 || index >= RF_NUM_ENV_VARS) return 0;
  if (!key_buf || key_buf_len <= 0 || !val_buf || val_buf_len <= 0) return 0;

  // Values are derived: index 0 -> manifest_file, 1|2 -> directory
  // (JAVA_RUNFILES aliases RUNFILES_DIR). No storage is allocated for
  // env values.
  const char* key = kRfEnvKeys[index];
  const char* val = (index == 0) ? rf->manifest_file : rf->directory;

  int klen = (int)strlen(key);
  int vlen = (int)strlen(val);
  if (klen + 1 > key_buf_len || vlen + 1 > val_buf_len) return 0;

  memcpy(key_buf, key, klen + 1);
  memcpy(val_buf, val, vlen + 1);
  return 1;
}

// ==========================================================================
// Destructor
// ==========================================================================

void rf_free(rf_runfiles* rf) { rf_free_impl(rf); }
