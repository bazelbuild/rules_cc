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
// Wrappers keep the vtable dispatch uniform -- no code path branches on
// "is this the default?".
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
// Allocator dispatch helpers.
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
// All filesystem and env-var access goes through W-variant Win32 APIs so
// non-ASCII paths / values don't get mangled by the process ANSI code
// page. Runfiles paths and env-var values are UTF-8 at the library
// boundary.
//
// rf_utf8_to_wide's output is always transient (freed on the same call
// stack), so libc malloc is fine for its fallback. rf_wide_to_utf8's
// output MAY escape to callers via rf_getenv_alloc, so its fallback
// routes through the pluggable allocator to keep caller-side free
// pairings correct.
// ==========================================================================

#ifdef _WIN32
// Caller must `if (result != stack_buf) free(result);` after use.
// Returns NULL on invalid UTF-8 or allocation failure.
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

// Result may escape to callers, so heap fallback routes through @p
// alloc (or libc if NULL). Caller frees through the matching path.
static char* rf_wide_to_utf8(const wchar_t* wide, char* stack_buf,
                             size_t stack_cap, const rf_allocator* alloc) {
  if (!wide) return NULL;
  int n = WideCharToMultiByte(CP_UTF8, 0, wide, -1, NULL, 0, NULL, NULL);
  if (n <= 0) return NULL;
  char* s;
  if ((size_t)n <= stack_cap) {
    s = stack_buf;
  } else if (alloc) {
    s = (char*)rf_a_malloc(alloc, (size_t)n);
  } else {
    s = (char*)malloc((size_t)n);
  }
  if (!s) return NULL;
  if (WideCharToMultiByte(CP_UTF8, 0, wide, -1, s, n, NULL, NULL) <= 0) {
    if (s != stack_buf) {
      if (alloc) {
        rf_a_free(alloc, s);
      } else {
        free(s);
      }
    }
    return NULL;
  }
  return s;
}
#endif  // _WIN32

// ==========================================================================
// rf_fopen_utf8 -- cross-platform fopen accepting UTF-8 paths.
// Windows routes through _wfopen; POSIX is plain fopen (paths already
// UTF-8 there).
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
  //
  // Backslash-only paths (`\foo`, `\\host\share`, `\\?\C:\...`) are
  // intentionally NOT treated as absolute -- matching the upstream
  // C++ `Runfiles::IsAbsolute` contract on every platform, so
  // callers get identical behaviour to the pre-C-port implementation.
  if (((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')) && path[1] == ':' &&
      (path[2] == '\\' || path[2] == '/'))
    return 1;
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

// GetEnvironmentVariableW on Windows so env vars set via
// SetEnvironmentVariableW (not visible through the CRT `_environ`
// block) and non-ASCII values both work; getenv on POSIX.
char* rf_getenv_alloc(const struct rf_allocator* alloc, const char* name) {
#ifdef _WIN32
  // Env-var names are ASCII, so ASCII -> UTF-16 is a straight widening
  // copy -- no MultiByteToWideChar call, no allocation.
  wchar_t wname[128];
  size_t i;
  for (i = 0; name[i] && i < sizeof(wname) / sizeof(wchar_t) - 1; i++) {
    wname[i] = (wchar_t)(unsigned char)name[i];
  }
  if (name[i]) return NULL;  // name too long for our stack buffer
  wname[i] = L'\0';

  DWORD wsize = GetEnvironmentVariableW(wname, NULL, 0);
  if (wsize == 0) return NULL;

  // The wide-char buffer is transient (freed on this call stack), but
  // we still route the heap fallback through @p alloc so a custom
  // allocator observes every byte of runfiles-attributable traffic.
  wchar_t stack_val[1024];
  wchar_t* wval;
  if ((size_t)wsize <= sizeof(stack_val) / sizeof(wchar_t)) {
    wval = stack_val;
  } else if (alloc) {
    wval = (wchar_t*)rf_a_malloc(alloc, (size_t)wsize * sizeof(wchar_t));
  } else {
    wval = (wchar_t*)malloc((size_t)wsize * sizeof(wchar_t));
  }
  if (!wval) return NULL;
  DWORD written = GetEnvironmentVariableW(wname, wval, wsize);
  if (written == 0 || written >= wsize) {
    if (wval != stack_val) {
      if (alloc) {
        rf_a_free(alloc, wval);
      } else {
        free(wval);
      }
    }
    return NULL;
  }
  // NULL stack buffer forces heap allocation via @p alloc.
  char* out = rf_wide_to_utf8(wval, NULL, 0, alloc);
  if (wval != stack_val) {
    if (alloc) {
      rf_a_free(alloc, wval);
    } else {
      free(wval);
    }
  }
  return out;
#else
  const char* v = getenv(name);
  if (!v) return NULL;
  size_t len = strlen(v);
  char* copy =
      alloc ? (char*)rf_a_malloc(alloc, len + 1) : (char*)malloc(len + 1);
  if (!copy) return NULL;
  memcpy(copy, v, len + 1);
  return copy;
#endif
}

int rf_path_is_rlocation_valid(const char* path) {
  if (!path || !path[0]) return 0;
  size_t len = strlen(path);
  // Treat '\' as a separator on ALL platforms -- Bazel manifests use
  // forward slashes, so a backslash in a caller-supplied key is
  // suspicious and rejecting it closes the Windows path-traversal
  // hole ("..\\..\\etc\\passwd") without a platform ifdef.
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

// Grow @p *buf to hold at least @p need bytes (including NUL). Doubles
// on each grow. Returns 1 on success, 0 on allocation failure (in which
// case @p *buf and @p *cap are left unchanged).
static int rf_buf_grow(char** buf, size_t* cap, size_t need,
                       const rf_allocator* alloc) {
  if (*cap >= need) return 1;
  size_t nc = *cap ? *cap : 128;
  while (nc < need) nc *= 2;
  char* np = (char*)rf_a_realloc(alloc, *buf, nc);
  if (!np) return 0;
  *buf = np;
  *cap = nc;
  return 1;
}

static int rf_buf_assign(char** buf, size_t* cap, const rf_allocator* alloc,
                         const char* s) {
  size_t l = strlen(s);
  if (!rf_buf_grow(buf, cap, l + 1, alloc)) return 0;
  memcpy(*buf, s, l + 1);
  return 1;
}

static int rf_buf_join2(char** buf, size_t* cap, const rf_allocator* alloc,
                        const char* a, const char* b) {
  size_t la = strlen(a);
  size_t lb = strlen(b);
  if (!rf_buf_grow(buf, cap, la + lb + 1, alloc)) return 0;
  memcpy(*buf, a, la);
  memcpy(*buf + la, b, lb);
  (*buf)[la + lb] = '\0';
  return 1;
}

static void rf_buf_truncate(char* buf, size_t new_len) { buf[new_len] = '\0'; }

// Predicate dispatch: caller override else the built-in. Keeps
// rf_paths_from_body free of null-check boilerplate.
#define RF_IS_FILE(path)                                           \
  (is_readable_file ? is_readable_file(predicate_userdata, (path)) \
                    : rf_is_readable_file(path))
#define RF_IS_DIR(path)                                    \
  (is_directory ? is_directory(predicate_userdata, (path)) \
                : rf_is_directory(path))

// Inner body -- buffers stay in the caller's locals so the wrapper can
// free them on either path. On success ownership of a valid buffer
// transfers to *out_manifest / *out_directory (local NULL'd).
static int rf_paths_from_body(
    const char* argv0, const char* runfiles_manifest_file,
    const char* runfiles_dir, rf_predicate is_readable_file,
    rf_predicate is_directory, void* predicate_userdata,
    const rf_allocator* alloc, char** mf_buf, size_t* mf_cap, char** dir_buf,
    size_t* dir_cap, char** out_manifest, char** out_directory) {
  const char* mf_in = runfiles_manifest_file ? runfiles_manifest_file : "";
  const char* dir_in = runfiles_dir ? runfiles_dir : "";

  if (!rf_buf_assign(mf_buf, mf_cap, alloc, mf_in)) return 0;
  if (!rf_buf_assign(dir_buf, dir_cap, alloc, dir_in)) return 0;

  int mf_valid = (*mf_buf)[0] && RF_IS_FILE(*mf_buf);
  int dir_valid = (*dir_buf)[0] && RF_IS_DIR(*dir_buf);

  if (argv0 && argv0[0] && !mf_valid && !dir_valid) {
    // argv0.runfiles/MANIFEST + argv0.runfiles
    if (!rf_buf_join2(mf_buf, mf_cap, alloc, argv0, kRunfilesSlashManifest))
      return 0;
    if (!rf_buf_join2(dir_buf, dir_cap, alloc, argv0, kRunfilesDir)) return 0;
    mf_valid = RF_IS_FILE(*mf_buf);
    dir_valid = RF_IS_DIR(*dir_buf);
    if (!mf_valid) {
      if (!rf_buf_join2(mf_buf, mf_cap, alloc, argv0, kRunfilesManifest))
        return 0;
      mf_valid = RF_IS_FILE(*mf_buf);
    }
  }

  if (!mf_valid && !dir_valid) return 0;

  if (!mf_valid) {
    // Try dir + "/MANIFEST" then dir + "_manifest".
    if (!rf_buf_join2(mf_buf, mf_cap, alloc, *dir_buf, kSlashManifest))
      return 0;
    mf_valid = RF_IS_FILE(*mf_buf);
    if (!mf_valid) {
      if (!rf_buf_join2(mf_buf, mf_cap, alloc, *dir_buf, kUnderscoreManifest))
        return 0;
      mf_valid = RF_IS_FILE(*mf_buf);
    }
  }

  if (!dir_valid) {
    // If mf ends with ".runfiles_manifest" or "/MANIFEST", derive the
    // directory by stripping the 9-char suffix ("_manifest" or
    // "/MANIFEST"). Each suffix check must guard against mf being
    // shorter than the suffix itself to avoid reading before *mf_buf.
    size_t mf_len = strlen(*mf_buf);
    const size_t kStripLen = 9;
    const size_t kRunfilesManifestLen = sizeof(kRunfilesManifest) - 1;
    const size_t kSlashManifestLen = sizeof(kSlashManifest) - 1;
    int matches =
        (mf_len >= kRunfilesManifestLen &&
         strcmp(*mf_buf + mf_len - kRunfilesManifestLen, kRunfilesManifest) ==
             0) ||
        (mf_len >= kSlashManifestLen &&
         strcmp(*mf_buf + mf_len - kSlashManifestLen, kSlashManifest) == 0);
    if (matches) {
      if (!rf_buf_grow(dir_buf, dir_cap, mf_len - kStripLen + 1, alloc))
        return 0;
      memcpy(*dir_buf, *mf_buf, mf_len - kStripLen);
      rf_buf_truncate(*dir_buf, mf_len - kStripLen);
      dir_valid = RF_IS_DIR(*dir_buf);
    }
  }

  // Hand ownership of the valid buffers to the caller. The invalid
  // one (and any buffer we allocated but didn't use) stays in
  // *mf_buf / *dir_buf for the wrapper to free.
  if (mf_valid) {
    *out_manifest = *mf_buf;
    *mf_buf = NULL;
  }
  if (dir_valid) {
    *out_directory = *dir_buf;
    *dir_buf = NULL;
  }
  return 1;
}

int rf_paths_from(const char* argv0, const char* runfiles_manifest_file,
                  const char* runfiles_dir, rf_predicate is_readable_file,
                  rf_predicate is_directory, void* predicate_userdata,
                  const struct rf_allocator* alloc, char** out_manifest,
                  char** out_directory) {
  if (!out_manifest || !out_directory) return 0;
  *out_manifest = NULL;
  *out_directory = NULL;
  if (!alloc) alloc = &g_libc_allocator;

  char* mf_buf = NULL;
  size_t mf_cap = 0;
  char* dir_buf = NULL;
  size_t dir_cap = 0;
  int ok = rf_paths_from_body(argv0, runfiles_manifest_file, runfiles_dir,
                              is_readable_file, is_directory,
                              predicate_userdata, alloc, &mf_buf, &mf_cap,
                              &dir_buf, &dir_cap, out_manifest, out_directory);
  rf_a_free(alloc, mf_buf);
  rf_a_free(alloc, dir_buf);
  return ok;
}
#undef RF_IS_FILE
#undef RF_IS_DIR

// ==========================================================================
// Streaming line reader
// ==========================================================================

// Read one line; strip trailing \r/\n. Returns line length, or -1 EOF /
// -2 I/O error / -3 alloc failure. Reads a byte at a time via the
// unlocked getc so embedded NULs are preserved (fgets+strlen would
// silently truncate them); unlocked is safe because the FILE* is
// function-local.
static int rf_read_line(FILE* f, char** line_buf, size_t* line_cap,
                        const rf_allocator* a) {
// Prefer the unlocked getc where we can — the FILE* is function-local
// so per-byte locking is pure overhead. Fall back to plain getc where
// no reliable unlocked variant exists (MinGW ships it conditional on
// __MSVCRT_VERSION__; Cygwin's newlib doesn't guarantee it either).
#if defined(_MSC_VER)
#define RF_GETC(fp) _getc_nolock(fp)
#elif !defined(_WIN32) && !defined(__CYGWIN__)
#define RF_GETC(fp) getc_unlocked(fp)
#else
#define RF_GETC(fp) getc(fp)
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
// Format helpers (pure -- no I/O, no allocation).
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
// Manifest parser (streaming, C-private). Only caller is rf_create,
// via the rf_build_manifest_cb callback below.
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
// rf_runfiles -- parsed state fully owned by one handle. No refcount, no
// sharing, no locking.
// ==========================================================================

// Sorted lexicographically by (target_apparent, source_repo) --
// reproduces std::pair<string,string>::operator< exactly, including
// "'*' sorts before every valid repo-name char" for wildcards.
typedef struct {
  char* target_apparent;
  size_t ta_len;
  char* source_repo;  // May end in '*' for wildcard entries.
  size_t sr_len;
  char* value;
  size_t value_len;
} rf_repo_entry;

// key_len cached so binary search doesn't strlen on every probe.
typedef struct {
  char* key;
  size_t key_len;
  char* value;
} rf_manifest_entry;

struct rf_runfiles {
  // Owned COPY of the allocator vtable, so callers may pass a
  // stack-local #rf_allocator to rf_create.
  rf_allocator alloc;

  char* directory;
  char* manifest_file;
  char* source_repository;

  rf_manifest_entry* manifest;
  size_t manifest_count;
  size_t manifest_capacity;

  rf_repo_entry* repo_map;
  size_t repo_map_count;
  size_t repo_map_capacity;

  // No separate env-var storage -- rf_env_var_value returns pointers
  // into manifest_file / directory.
};

// ==========================================================================
// Sort comparators
// ==========================================================================

// Length-aware to match rf_bsearch_manifest_prefix's memcmp+length
// compare byte-for-byte. strcmp would disagree with the lookup path on
// any key containing an embedded NUL (the streaming reader preserves
// them).
static int rf_manifest_qsort_cmp(const void* a, const void* b) {
  const rf_manifest_entry* ea = (const rf_manifest_entry*)a;
  const rf_manifest_entry* eb = (const rf_manifest_entry*)b;
  size_t n = ea->key_len < eb->key_len ? ea->key_len : eb->key_len;
  int c = n ? memcmp(ea->key, eb->key, n) : 0;
  if (c != 0) return c;
  if (ea->key_len < eb->key_len) return -1;
  if (ea->key_len > eb->key_len) return 1;
  return 0;
}

// Lex compare on (target_apparent, source_repo). Shared by the sort
// and the lookup so both paths agree on ordering (incl. '*' sorting
// before every valid repo-name char for wildcards).
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
// Parser callbacks
//
// Non-zero return propagates through the parser as RF_ERR_CALLBACK and
// unwinds the whole build path, so returning non-zero on OOM doubles
// as error propagation -- no separate flag needed.
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
//
// Caller-buffer contract: writes NUL-terminated result into @p buf when
// it fits, always sets @c *needed so callers can grow-and-retry once
// with an exactly-sized buffer. Internal encoding:
//   1  -> OK (buf written, *needed = strlen)
//   0  -> NOT_FOUND
//   -1 -> BUF_TOO_SMALL (buf untouched, *needed = required)
//   -2 -> ALLOC_FAILED (only from rf_rlocation_unchecked_join's scratch)
// ==========================================================================

// Passing `strlen(path)` as prefix_len is an exact-key search. Never
// mutates @p path.
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

// Never allocates.
static int rf_rlocation_unchecked(const rf_runfiles* rf, const char* path,
                                  char* buf, size_t buf_cap, size_t* needed) {
  *needed = 0;
  size_t path_len = strlen(path);

  // 1) Exact match.
  int idx = rf_bsearch_manifest_prefix(rf, path, path_len);
  if (idx >= 0) {
    const char* v = rf->manifest[idx].value;
    size_t vlen = strlen(v);
    *needed = vlen;
    if (vlen + 1 > buf_cap) return -1;
    memcpy(buf, v, vlen + 1);
    return 1;
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
        size_t vlen = strlen(v);
        size_t rem_len = path_len - prefix_end - 1;
        size_t total = vlen + 1 + rem_len;
        *needed = total;
        if (total + 1 > buf_cap) return -1;
        memcpy(buf, v, vlen);
        buf[vlen] = '/';
        memcpy(buf + vlen + 1, path + prefix_end + 1, rem_len);
        buf[total] = '\0';
        return 1;
      }
    }
  }

  // 3) Directory fallback.
  if (rf->directory && rf->directory[0]) {
    size_t dlen = strlen(rf->directory);
    size_t total = dlen + 1 + path_len;
    *needed = total;
    if (total + 1 > buf_cap) return -1;
    memcpy(buf, rf->directory, dlen);
    buf[dlen] = '/';
    memcpy(buf + dlen + 1, path, path_len + 1);
    return 1;
  }
  return 0;
}

// Post-repo-mapping variant: builds a virtual "prefix + suffix" key in
// allocator-backed scratch, delegates the lookup, frees. Returns -2
// if the scratch alloc fails -- the ONE alloc the caller-buffer public
// API makes internally, bounded by prefix_len + suffix_len.
static int rf_rlocation_unchecked_join(const rf_runfiles* rf,
                                       const char* prefix, size_t prefix_len,
                                       const char* suffix, size_t suffix_len,
                                       char* buf, size_t buf_cap,
                                       size_t* needed) {
  const rf_allocator* a = &rf->alloc;
  *needed = 0;
  size_t total = prefix_len + suffix_len;
  char* key = (char*)rf_a_malloc(a, total + 1);
  if (!key) return -2;
  memcpy(key, prefix, prefix_len);
  if (suffix_len) memcpy(key + prefix_len, suffix, suffix_len);
  key[total] = '\0';
  int r = rf_rlocation_unchecked(rf, key, buf, buf_cap, needed);
  rf_a_free(a, key);
  return r;
}

// ==========================================================================
// Public API -- construction
// ==========================================================================

// Also used by rf_create's mid-construction error paths.
static void rf_free_impl(rf_runfiles* rf) {
  if (!rf) return;
  // Snapshot the vtable so dispatch still works after `rf` is freed.
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

rf_runfiles* rf_create(const rf_allocator* alloc, const char* argv0,
                       const char* manifest, const char* dir,
                       const char* source_repo, char* err, size_t err_len) {
  if (!alloc) alloc = &g_libc_allocator;

  char* resolved_manifest = NULL;
  char* resolved_directory = NULL;
  if (!rf_paths_from(argv0 ? argv0 : "", manifest, dir, NULL, NULL, NULL, alloc,
                     &resolved_manifest, &resolved_directory)) {
    if (err && err_len > 0) {
      snprintf(err, err_len, "ERROR: cannot find runfiles (argv0=\"%s\")",
               argv0 ? argv0 : "");
    }
    return NULL;
  }

  rf_runfiles* rf = (rf_runfiles*)rf_a_malloc(alloc, sizeof(rf_runfiles));
  if (!rf) {
    rf_a_free(alloc, resolved_manifest);
    rf_a_free(alloc, resolved_directory);
    return NULL;
  }
  memset(rf, 0, sizeof(*rf));
  rf->alloc = *alloc;  // owned copy -- safe against short-lived vtables

  rf->directory =
      rf_a_strdup(alloc, resolved_directory ? resolved_directory : "");
  rf->manifest_file =
      rf_a_strdup(alloc, resolved_manifest ? resolved_manifest : "");
  rf->source_repository = rf_a_strdup(alloc, source_repo ? source_repo : "");
  if (!rf->directory || !rf->manifest_file || !rf->source_repository) {
    rf_a_free(alloc, resolved_manifest);
    rf_a_free(alloc, resolved_directory);
    rf_free_impl(rf);
    return NULL;
  }

  if (resolved_manifest && resolved_manifest[0]) {
    rf_status s = rf_parse_manifest_into(
        resolved_manifest, rf_build_manifest_cb, rf, err, (int)err_len, alloc);
    if (s != RF_OK) {
      rf_a_free(alloc, resolved_manifest);
      rf_a_free(alloc, resolved_directory);
      rf_free_impl(rf);
      return NULL;
    }
    if (rf->manifest_count > 1)
      qsort(rf->manifest, rf->manifest_count, sizeof(rf_manifest_entry),
            rf_manifest_qsort_cmp);
  }
  rf_a_free(alloc, resolved_manifest);
  rf_a_free(alloc, resolved_directory);

  // Resolve _repo_mapping. Stack buffer covers ~all real paths; on
  // BUF_TOO_SMALL retry once with the reported size.
  {
    char stack_buf[4096];
    char* heap_buf = NULL;
    char* buf = stack_buf;
    size_t cap = sizeof(stack_buf);
    size_t needed = 0;
    int r = rf_rlocation_unchecked(rf, "_repo_mapping", buf, cap, &needed);
    if (r == -1) {
      heap_buf = (char*)rf_a_malloc(alloc, needed + 1);
      if (!heap_buf) {
        rf_free_impl(rf);
        return NULL;
      }
      buf = heap_buf;
      cap = needed + 1;
      r = rf_rlocation_unchecked(rf, "_repo_mapping", buf, cap, &needed);
    }
    if (r == 1 && buf[0]) {
      rf_status s = rf_parse_repo_mapping_into(buf, rf_build_repo_map_cb, rf,
                                               err, (int)err_len, alloc);
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

rf_runfiles* rf_create_for_test(const rf_allocator* alloc,
                                const char* source_repo, char* err,
                                size_t err_len) {
  // Snapshot so the transient env-var strings get freed via the same
  // vtable rf_getenv_alloc allocated them with.
  const rf_allocator* env_alloc = alloc ? alloc : &g_libc_allocator;
  char* mf = rf_getenv_alloc(env_alloc, "RUNFILES_MANIFEST_FILE");
  char* dir = rf_getenv_alloc(env_alloc, "TEST_SRCDIR");
  rf_runfiles* r = rf_create(alloc, "", mf ? mf : "", dir ? dir : "",
                             source_repo, err, err_len);
  rf_a_free(env_alloc, mf);
  rf_a_free(env_alloc, dir);
  return r;
}

// ==========================================================================
// Public API -- free
// ==========================================================================

void rf_free(rf_runfiles* rf) { rf_free_impl(rf); }

// ==========================================================================
// Rlocation (with repo-mapping)
// ==========================================================================

static int rf_cmp_lookup_key(const rf_repo_entry* e,
                             const char* target_apparent, size_t ta_len,
                             const char* source_repo, size_t sr_len) {
  return rf_repo_key_cmp(e->target_apparent, e->ta_len, e->source_repo,
                         e->sr_len, target_apparent, ta_len, source_repo,
                         sr_len);
}

// upper_bound(key): index of first entry strictly greater than
// (target_apparent, source_repo). Returns repo_map_count if none.
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

static rf_rlocation_status rf_map_unchecked_status(int r) {
  switch (r) {
    case 1:
      return RF_RLOCATION_OK;
    case 0:
      return RF_RLOCATION_NOT_FOUND;
    case -1:
      return RF_RLOCATION_BUF_TOO_SMALL;
    default:
      return RF_RLOCATION_ALLOC_FAILED;
  }
}

rf_rlocation_status rf_rlocation(rf_runfiles* rf, const char* path,
                                 const char* source_repository, char* buf,
                                 size_t buf_cap, size_t* needed) {
  size_t local_needed = 0;
  if (!needed) needed = &local_needed;
  *needed = 0;

  if (!rf || !path) return RF_RLOCATION_INVALID_PATH;
  if (!rf_path_is_rlocation_valid(path)) return RF_RLOCATION_INVALID_PATH;

  if (rf_is_absolute(path)) {
    size_t plen = strlen(path);
    *needed = plen;
    if (plen + 1 > buf_cap) return RF_RLOCATION_BUF_TOO_SMALL;
    memcpy(buf, path, plen + 1);
    return RF_RLOCATION_OK;
  }

  const char* sr =
      source_repository ? source_repository : rf->source_repository;
  size_t sr_len = strlen(sr);

  const char* slash = strchr(path, '/');
  if (!slash || rf->repo_map_count == 0) {
    return rf_map_unchecked_status(
        rf_rlocation_unchecked(rf, path, buf, buf_cap, needed));
  }

  size_t first_slash = (size_t)(slash - path);
  size_t ub = rf_rm_upper_bound(rf, path, first_slash, sr, sr_len);
  // C++ std::prev(begin()) semantic: when ub sits at begin(), floor
  // stays at begin() so we still inspect the first entry -- it may be a
  // wildcard whose target_apparent matches ours, in which case
  // rewriting must fire even though the entry sorts strictly greater.
  size_t floor = (ub == 0) ? 0 : ub - 1;
  const rf_repo_entry* e = &rf->repo_map[floor];
  int cmp = rf_cmp_lookup_key(e, path, first_slash, sr, sr_len);
  const char* suffix = path + first_slash;
  size_t suffix_len = strlen(suffix);
  // Wildcard: entry.target_apparent == lookup.target_apparent,
  // entry.source_repo ends in '*', and lookup.source_repo starts with
  // the prefix (source_repo before the '*').
  int wildcard_match = e->ta_len == first_slash &&
                       memcmp(e->target_apparent, path, first_slash) == 0 &&
                       e->sr_len > 0 && e->source_repo[e->sr_len - 1] == '*' &&
                       e->sr_len - 1 <= sr_len &&
                       memcmp(e->source_repo, sr, e->sr_len - 1) == 0;
  int r;
  if (cmp == 0 || wildcard_match) {
    r = rf_rlocation_unchecked_join(rf, e->value, e->value_len, suffix,
                                    suffix_len, buf, buf_cap, needed);
  } else {
    r = rf_rlocation_unchecked(rf, path, buf, buf_cap, needed);
  }
  return rf_map_unchecked_status(r);
}

// ==========================================================================
// Envvars
// ==========================================================================

// JAVA_RUNFILES aliases RUNFILES_DIR -- compatibility shim for the Java
// launcher. TODO(laszlocsomor): remove once the launcher picks up
// RUNFILES_DIR directly.
static const char* const kRfEnvKeys[RF_NUM_ENV_VARS] = {
    "RUNFILES_MANIFEST_FILE", "RUNFILES_DIR", "JAVA_RUNFILES"};

int rf_env_vars_count(void) { return RF_NUM_ENV_VARS; }

const char* rf_env_var_key(int index) {
  if (index < 0 || index >= RF_NUM_ENV_VARS) return NULL;
  return kRfEnvKeys[index];
}

const char* rf_env_var_value(rf_runfiles* rf, int index) {
  if (!rf || index < 0 || index >= RF_NUM_ENV_VARS) return NULL;
  // index 0 -> manifest_file, 1|2 -> directory.
  return (index == 0) ? rf->manifest_file : rf->directory;
}
