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

/// @file runfiles_c_test.c
/// @brief Pure-C smoketest for the runfiles C API.
///
/// Complements runfiles_c_test.cc (which is C++/googletest) by exercising
/// the public C headers from a real C translation unit — proves the API
/// compiles under C, that no C++-only syntax has leaked into the public
/// header, and that the `extern "C"` boundary works end-to-end. Deliberately
/// small: this is a smoketest, not a replacement for the full C++ suite.
///
/// ### Structure
/// Each test is a `static int test_<name>(void)` returning the number of
/// assertion failures it observed (0 = pass). `main()` iterates the
/// `g_tests` array, prints gtest-style RUN/OK/FAILED banners, and exits
/// non-zero if any test failed.

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

// CHECK macros expect the enclosing test function to have an `int fails`
// in scope; each failure increments it. The test returns `fails` as its
// assertion-failure count.
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

// Manifest created once in main and shared across tests via the C
// library's per-(manifest, directory) cache. Bazel gives each test its
// own TEST_TMPDIR so the fixed filename does not collide across tests.
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

// Open a runfiles handle against the shared manifest. Returns NULL and
// prints diagnostics on failure so the caller can bail early.
static rf_runfiles* open_rf(void) {
  char err[256] = {0};
  rf_runfiles* rf = rf_create_ex(NULL, "", g_mf_path, "", "", err, sizeof(err));
  if (!rf) fprintf(stderr, "    rf_create_ex failed: %s\n", err);
  return rf;
}

// ==========================================================================
// Tests
// ==========================================================================

/// Standalone smoketest for #rf_is_absolute.
///
/// No runfiles state required — the function is pure and stateless.
/// Covers: POSIX leading-`/`, Windows drive-letter (`C:/`), a relative
/// path, the empty string, and `NULL`. Deliberately does NOT cover the
/// Windows-only UNC (`\\host\share`) branch — that would need a
/// platform-conditional expectation and lives in the C++ suite.
static int test_is_absolute(void) {
  int fails = 0;
  CHECK_EQ_INT(rf_is_absolute("/absolute/path"), 1, "unix absolute");
  CHECK_EQ_INT(rf_is_absolute("C:/foo"), 1, "drive-letter absolute");
  CHECK_EQ_INT(rf_is_absolute("relative/path"), 0, "relative rejected");
  CHECK_EQ_INT(rf_is_absolute(""), 0, "empty rejected");
  CHECK_EQ_INT(rf_is_absolute(NULL), 0, "NULL rejected");
  return fails;
}

/// Handle construction plus the three golden `rf_rlocation` paths.
///
/// Covers:
///   - #rf_create_ex against an explicit manifest path (bypassing env
///     and argv0 discovery).
///   - Exact-match lookup: `"hello/world"` → `"resolved/hello/world"`.
///   - Second exact-match to prove multiple entries in the parsed
///     manifest are indexed correctly.
///   - Longest-prefix fallback: `"nested/dir/inner/file"` should hit
///     the `"nested/dir"` prefix and append the remainder.
///   - Unknown key in manifest-only mode returns 0 (not -1, not the
///     directory fallback — no directory was configured).
static int test_create_and_lookup(void) {
  int fails = 0;
  rf_runfiles* rf = open_rf();
  CHECK(rf != NULL, "rf_create_ex succeeds");
  if (!rf) return fails + 1;

  char buf[1024];
  int n;

  n = rf_rlocation(rf, "hello/world", buf, sizeof(buf));
  CHECK(n > 0, "hello/world resolves");
  if (n > 0) CHECK_EQ_STR(buf, "resolved/hello/world", "hello/world value");

  n = rf_rlocation(rf, "data/config.json", buf, sizeof(buf));
  CHECK(n > 0, "data/config.json resolves");
  if (n > 0) CHECK_EQ_STR(buf, "config/config.json", "data/config.json value");

  n = rf_rlocation(rf, "nested/dir/inner/file", buf, sizeof(buf));
  CHECK(n > 0, "nested prefix match resolves");
  if (n > 0)
    CHECK_EQ_STR(buf, "resolved/nested/dir/inner/file", "prefix-match value");

  n = rf_rlocation(rf, "does/not/exist", buf, sizeof(buf));
  CHECK_EQ_INT(n, 0, "unknown key returns 0 (manifest-only mode)");

  rf_free(rf);
  return fails;
}

/// #rf_path_is_rlocation_valid rejection paths surfaced through
/// #rf_rlocation.
///
/// Covers the malformed-input contract that the validator locks in:
///   - Empty string → `-1`.
///   - Forward-slash traversal (`../etc/passwd`).
///   - **Backslash traversal (`..\etc\passwd`)** — a regression guard
///     for the Windows path-traversal fix; the validator now treats
///     `\` as a separator on all platforms so this input can never
///     escape the runfiles tree.
///   - Embedded `/../` mid-path.
static int test_rejects_bad_paths(void) {
  int fails = 0;
  rf_runfiles* rf = open_rf();
  CHECK(rf != NULL, "rf_create_ex succeeds");
  if (!rf) return fails + 1;

  char buf[1024];
  CHECK_EQ_INT(rf_rlocation(rf, "", buf, sizeof(buf)), -1, "empty rejected");
  CHECK_EQ_INT(rf_rlocation(rf, "../etc/passwd", buf, sizeof(buf)), -1,
               "forward-slash traversal rejected");
  CHECK_EQ_INT(rf_rlocation(rf, "..\\etc\\passwd", buf, sizeof(buf)), -1,
               "backslash traversal rejected");
  CHECK_EQ_INT(rf_rlocation(rf, "a/../b", buf, sizeof(buf)), -1,
               "embedded /../ rejected");

  rf_free(rf);
  return fails;
}

/// Verify that an absolute input to #rf_rlocation passes through
/// verbatim.
///
/// Absolute paths are the documented escape hatch for callers that
/// already have a resolved on-disk path. The function must NOT prepend
/// the runfiles directory, apply repo-mapping, or consult the manifest.
static int test_absolute_passthrough(void) {
  int fails = 0;
  rf_runfiles* rf = open_rf();
  CHECK(rf != NULL, "rf_create_ex succeeds");
  if (!rf) return fails + 1;

  char buf[1024];
  int n = rf_rlocation(rf, "/tmp/already-absolute", buf, sizeof(buf));
  CHECK(n > 0, "absolute path passes through");
  if (n > 0)
    CHECK_EQ_STR(buf, "/tmp/already-absolute", "absolute path unchanged");

  rf_free(rf);
  return fails;
}

/// #rf_env_vars_count and #rf_env_var: the subprocess-env-publish API.
///
/// Covers:
///   - Fixed count of 3 (`RUNFILES_MANIFEST_FILE`, `RUNFILES_DIR`,
///     `JAVA_RUNFILES`).
///   - Reading the first pair returns the manifest key and the exact
///     manifest path we passed to #rf_create_ex.
///   - Out-of-range index returns 0 (does NOT crash and does NOT write
///     past the buffers).
static int test_env_var(void) {
  int fails = 0;
  rf_runfiles* rf = open_rf();
  CHECK(rf != NULL, "rf_create_ex succeeds");
  if (!rf) return fails + 1;

  CHECK_EQ_INT(rf_env_vars_count(rf), 3, "3 env vars");
  char k[128], v[4096];
  CHECK_EQ_INT(rf_env_var(rf, 0, k, sizeof(k), v, sizeof(v)), 1,
               "env_var[0] readable");
  CHECK_EQ_STR(k, "RUNFILES_MANIFEST_FILE", "env_var[0] key");
  CHECK_EQ_STR(v, g_mf_path, "env_var[0] value is manifest path");
  CHECK_EQ_INT(rf_env_var(rf, 42, k, sizeof(k), v, sizeof(v)), 0,
               "out-of-range env_var rejected");

  rf_free(rf);
  return fails;
}

/// `rf_free(NULL)` is a documented no-op.
///
/// Guards against a common footgun (unconditional cleanup on the error
/// path where the handle may never have been allocated). The check
/// simply proves control returned; the test would crash instead of
/// failing an assertion if the contract were violated.
static int test_free_null(void) {
  int fails = 0;
  rf_free(NULL);  // NULL is documented as a no-op.
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
