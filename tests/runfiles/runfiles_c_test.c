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

// Pure-C smoketest. Proves the public C API compiles from a real C TU
// (no C++-only syntax leaked into the header, extern "C" boundary
// works). Deliberately tiny -- the full suite is in runfiles_c_test.cc.

#include "rules_cc/cc/runfiles/runfiles_c.h"

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <direct.h>
#include <io.h>
#define UNLINK(p) _unlink(p)
#else
#include <unistd.h>
#define UNLINK(p) unlink(p)
#endif

// The enclosing test must declare `int fails` -- each failed check
// increments it, and the test returns `fails` as its failure count.
#define CHECK(cond, msg)                                           \
  do {                                                             \
    if (cond) {                                                    \
      printf("    pass: %s\n", (msg));                             \
    } else {                                                       \
      printf("    FAIL: %s (%s:%d)\n", (msg), __FILE__, __LINE__); \
      ++fails;                                                     \
    }                                                              \
  } while (0)

#define CHECK_EQ_INT(actual, expected, msg)                              \
  do {                                                                   \
    long a_ = (long)(actual);                                            \
    long e_ = (long)(expected);                                          \
    if (a_ == e_) {                                                      \
      printf("    pass: %s\n", (msg));                                   \
    } else {                                                             \
      printf("    FAIL: %s: got %ld, want %ld (%s:%d)\n", (msg), a_, e_, \
             __FILE__, __LINE__);                                        \
      ++fails;                                                           \
    }                                                                    \
  } while (0)

#define CHECK_EQ_STR(actual, expected, msg)                                    \
  do {                                                                         \
    const char* a_ = (actual);                                                 \
    const char* e_ = (expected);                                               \
    if (strcmp(a_, e_) == 0) {                                                 \
      printf("    pass: %s\n", (msg));                                         \
    } else {                                                                   \
      printf("    FAIL: %s: got \"%s\", want \"%s\" (%s:%d)\n", (msg), a_, e_, \
             __FILE__, __LINE__);                                              \
      ++fails;                                                                 \
    }                                                                          \
  } while (0)

// Shared across tests via TEST_TMPDIR (which Bazel isolates per test).
static char g_mf_path[4096];

static void cleanup_mf(void) {
  if (g_mf_path[0]) UNLINK(g_mf_path);
}

static int create_manifest(void) {
  const char* tmp = getenv("TEST_TMPDIR");
  if (!tmp || !tmp[0]) {
    fprintf(stderr, "TEST_TMPDIR is unset\n");
    return 0;
  }
  int written = snprintf(g_mf_path, sizeof(g_mf_path),
                         "%s/runfiles_c_test.runfiles_manifest", tmp);
  if (written <= 0 || (size_t)written >= sizeof(g_mf_path)) return 0;
  atexit(cleanup_mf);

  FILE* f = fopen(g_mf_path, "w");
  if (!f) {
    fprintf(stderr, "cannot open %s: %s\n", g_mf_path, strerror(errno));
    return 0;
  }
  fputs("hello/world resolved/hello/world\n", f);
  fputs("data/config.json config/config.json\n", f);
  fputs("nested/dir resolved/nested/dir\n", f);
  fclose(f);
  return 1;
}

static rf_runfiles* open_rf(void) {
  char err[256] = {0};
  rf_runfiles* rf = rf_create(NULL, "", g_mf_path, "", "", err, sizeof(err));
  if (!rf) fprintf(stderr, "    rf_create failed: %s\n", err);
  return rf;
}

// ==========================================================================
// Tests
// ==========================================================================

// UNC (`\\host\share`) is in the C++ suite (needs platform ifdef).
static int test_is_absolute(void) {
  int fails = 0;
  CHECK_EQ_INT(rf_is_absolute("/absolute/path"), 1, "unix absolute");
  CHECK_EQ_INT(rf_is_absolute("C:/foo"), 1, "drive-letter absolute");
  CHECK_EQ_INT(rf_is_absolute("relative/path"), 0, "relative rejected");
  CHECK_EQ_INT(rf_is_absolute(""), 0, "empty rejected");
  CHECK_EQ_INT(rf_is_absolute(NULL), 0, "NULL rejected");
  return fails;
}

static int test_create_and_lookup(void) {
  int fails = 0;
  rf_runfiles* rf = open_rf();
  CHECK(rf != NULL, "rf_create succeeds");
  if (!rf) return fails + 1;

  char buf[1024];
  size_t needed = 0;
  rf_rlocation_status s;

  s = rf_rlocation(rf, "hello/world", NULL, buf, sizeof(buf), &needed);
  CHECK_EQ_INT(s, RF_RLOCATION_OK, "hello/world resolves");
  if (s == RF_RLOCATION_OK) {
    CHECK_EQ_STR(buf, "resolved/hello/world", "hello/world value");
    CHECK_EQ_INT(needed, strlen("resolved/hello/world"),
                 "needed == strlen(result)");
  }

  s = rf_rlocation(rf, "data/config.json", NULL, buf, sizeof(buf), &needed);
  CHECK_EQ_INT(s, RF_RLOCATION_OK, "data/config.json resolves");
  if (s == RF_RLOCATION_OK)
    CHECK_EQ_STR(buf, "config/config.json", "data/config.json value");

  s = rf_rlocation(rf, "nested/dir/inner/file", NULL, buf, sizeof(buf),
                   &needed);
  CHECK_EQ_INT(s, RF_RLOCATION_OK, "nested prefix match resolves");
  if (s == RF_RLOCATION_OK)
    CHECK_EQ_STR(buf, "resolved/nested/dir/inner/file", "prefix-match value");

  s = rf_rlocation(rf, "does/not/exist", NULL, buf, sizeof(buf), &needed);
  CHECK_EQ_INT(s, RF_RLOCATION_NOT_FOUND,
               "unknown key returns NOT_FOUND (manifest-only mode)");
  CHECK_EQ_INT(needed, 0, "NOT_FOUND leaves needed=0");

  rf_free(rf);
  return fails;
}

// Backslash traversal case is the regression guard for the
// Windows path-traversal hole -- `\` is a separator on all platforms.
static int test_rejects_bad_paths(void) {
  int fails = 0;
  rf_runfiles* rf = open_rf();
  CHECK(rf != NULL, "rf_create succeeds");
  if (!rf) return fails + 1;

  char buf[1024];
  size_t needed = 0;
  CHECK_EQ_INT(rf_rlocation(rf, "", NULL, buf, sizeof(buf), &needed),
               RF_RLOCATION_INVALID_PATH, "empty rejected");
  CHECK_EQ_INT(
      rf_rlocation(rf, "../etc/passwd", NULL, buf, sizeof(buf), &needed),
      RF_RLOCATION_INVALID_PATH, "forward-slash traversal rejected");
  CHECK_EQ_INT(
      rf_rlocation(rf, "..\\etc\\passwd", NULL, buf, sizeof(buf), &needed),
      RF_RLOCATION_INVALID_PATH, "backslash traversal rejected");
  CHECK_EQ_INT(rf_rlocation(rf, "a/../b", NULL, buf, sizeof(buf), &needed),
               RF_RLOCATION_INVALID_PATH, "embedded /../ rejected");

  rf_free(rf);
  return fails;
}

static int test_absolute_passthrough(void) {
  int fails = 0;
  rf_runfiles* rf = open_rf();
  CHECK(rf != NULL, "rf_create succeeds");
  if (!rf) return fails + 1;

  char buf[1024];
  size_t needed = 0;
  rf_rlocation_status s = rf_rlocation(rf, "/tmp/already-absolute", NULL, buf,
                                       sizeof(buf), &needed);
  CHECK_EQ_INT(s, RF_RLOCATION_OK, "absolute path passes through");
  if (s == RF_RLOCATION_OK)
    CHECK_EQ_STR(buf, "/tmp/already-absolute", "absolute path unchanged");

  rf_free(rf);
  return fails;
}

static int test_buf_too_small(void) {
  int fails = 0;
  rf_runfiles* rf = open_rf();
  CHECK(rf != NULL, "rf_create succeeds");
  if (!rf) return fails + 1;

  // Try with a 4-byte buffer; result is "resolved/hello/world" (20 chars).
  char tiny[4];
  const char sentinel = '\x7f';
  memset(tiny, sentinel, sizeof(tiny));
  size_t needed = 0;
  rf_rlocation_status s =
      rf_rlocation(rf, "hello/world", NULL, tiny, sizeof(tiny), &needed);
  CHECK_EQ_INT(s, RF_RLOCATION_BUF_TOO_SMALL, "tiny buffer -> BUF_TOO_SMALL");
  CHECK_EQ_INT(needed, strlen("resolved/hello/world"), "needed = full length");
  CHECK_EQ_INT(tiny[0], sentinel, "buf untouched on BUF_TOO_SMALL[0]");
  CHECK_EQ_INT(tiny[3], sentinel, "buf untouched on BUF_TOO_SMALL[3]");

  // Query-only: NULL buf, 0 cap.
  size_t query_needed = 0;
  s = rf_rlocation(rf, "hello/world", NULL, NULL, 0, &query_needed);
  CHECK_EQ_INT(s, RF_RLOCATION_BUF_TOO_SMALL,
               "query-only NULL/0 -> BUF_TOO_SMALL");
  CHECK_EQ_INT(query_needed, strlen("resolved/hello/world"),
               "query needed = full length");

  // Retry with exact size.
  char* heap = (char*)malloc(needed + 1);
  CHECK(heap != NULL, "malloc succeeded");
  if (heap) {
    s = rf_rlocation(rf, "hello/world", NULL, heap, needed + 1, &needed);
    CHECK_EQ_INT(s, RF_RLOCATION_OK, "retry with exact size succeeds");
    if (s == RF_RLOCATION_OK)
      CHECK_EQ_STR(heap, "resolved/hello/world", "retry result correct");
    free(heap);
  }

  rf_free(rf);
  return fails;
}

static int test_env_var(void) {
  int fails = 0;
  rf_runfiles* rf = open_rf();
  CHECK(rf != NULL, "rf_create succeeds");
  if (!rf) return fails + 1;

  CHECK_EQ_INT(rf_env_vars_count(), 3, "3 env vars");
  const char* k = rf_env_var_key(0);
  const char* v = rf_env_var_value(rf, 0);
  CHECK(k != NULL, "env_var_key[0] readable");
  CHECK(v != NULL, "env_var_value[0] readable");
  if (k) CHECK_EQ_STR(k, "RUNFILES_MANIFEST_FILE", "env_var[0] key");
  if (v) CHECK_EQ_STR(v, g_mf_path, "env_var[0] value is manifest path");
  CHECK(rf_env_var_key(42) == NULL, "out-of-range key returns NULL");
  CHECK(rf_env_var_value(rf, 42) == NULL, "out-of-range value returns NULL");

  rf_free(rf);
  return fails;
}

static int test_free_null(void) {
  int fails = 0;
  rf_free(NULL);
  CHECK(1, "rf_free(NULL) returned without crashing");
  return fails;
}

// ==========================================================================
// Runner
// ==========================================================================

typedef int (*test_fn)(void);
typedef struct {
  const char* name;
  test_fn fn;
} test_case;

static const test_case g_tests[] = {
    {"IsAbsolute", test_is_absolute},
    {"CreateAndLookup", test_create_and_lookup},
    {"RejectsBadPaths", test_rejects_bad_paths},
    {"AbsolutePassthrough", test_absolute_passthrough},
    {"BufTooSmall", test_buf_too_small},
    {"EnvVar", test_env_var},
    {"FreeNull", test_free_null},
};

int main(void) {
  printf("== runfiles_c_test.c (pure C smoketest) ==\n");
  if (!create_manifest()) return 1;

  const int n_tests = (int)(sizeof(g_tests) / sizeof(g_tests[0]));
  int total_fails = 0;
  int failed_tests = 0;

  for (int i = 0; i < n_tests; i++) {
    printf("[ RUN      ] %s\n", g_tests[i].name);
    int f = g_tests[i].fn();
    if (f == 0) {
      printf("[       OK ] %s\n", g_tests[i].name);
    } else {
      printf("[  FAILED  ] %s (%d assertion failure(s))\n", g_tests[i].name, f);
      failed_tests++;
    }
    total_fails += f;
  }

  printf("\n== %d test(s): %d passed, %d failed (%d assertion failure(s)) ==\n",
         n_tests, n_tests - failed_tests, failed_tests, total_fails);
  return total_fails == 0 ? 0 : 1;
}
