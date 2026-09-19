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

extern "C" {
#include "rules_cc/cc/runfiles/runfiles_c.h"
}

#ifdef _WIN32
#include <direct.h>
#include <windows.h>
// MSVC's <direct.h> spells these _mkdir(path) (no mode) and _rmdir(path).
// Alias them to the POSIX names so the test body reads identically on
// both platforms.
#define mkdir(path, mode) _mkdir(path)
#define rmdir(path) _rmdir(path)
#else
#include <sys/stat.h>
#include <unistd.h>
#endif

#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <memory>
#include <string>
#include <vector>

#include "gtest/gtest.h"

namespace {

#define RUNFILES_C_TEST_TOSTRING_HELPER(x) #x
#define RUNFILES_C_TEST_TOSTRING(x) RUNFILES_C_TEST_TOSTRING_HELPER(x)
#define LINE_AS_STRING() RUNFILES_C_TEST_TOSTRING(__LINE__)

// TEST_TMPDIR into a std::string, asserting it exists so a direct-run
// fails cleanly rather than crashing on std::string(nullptr).
#define ASSERT_TMPDIR(local)                            \
  const char* local##_env = std::getenv("TEST_TMPDIR"); \
  ASSERT_TRUE(local##_env&& local##_env[0]);            \
  const std::string local = local##_env

using std::string;
using std::unique_ptr;
using std::vector;

// Common-case shortcuts; tests reach for full rf_create when they
// need a custom allocator or a non-default source repo.
static rf_runfiles* MakeFromArgv0(const string& argv0, char err[256]) {
  return rf_create(nullptr, argv0.c_str(), "", "", "", err, 256);
}
static rf_runfiles* MakeFromManifest(const string& manifest, char err[256]) {
  return rf_create(nullptr, "", manifest.c_str(), "", "", err, 256);
}

// Temp file that self-deletes.
class MockFile {
 public:
  static MockFile* Create(const string& name) {
    return Create(name, vector<string>());
  }

  static MockFile* Create(const string& name, const vector<string>& lines) {
    if (name.find("..") != string::npos || rf_is_absolute(name.c_str())) {
      return nullptr;
    }
    const char* tmp = std::getenv("TEST_TMPDIR");
    if (!tmp || !tmp[0]) return nullptr;
    string root(tmp);
    string path = root + "/" + name;

    string::size_type i = 0;
    while ((i = name.find_first_of('/', i + 1)) != string::npos) {
      string d = root + "/" + name.substr(0, i);
      if (mkdir(d.c_str(), 0777) != 0 && errno != EEXIST) return nullptr;
    }
    std::ofstream stm(path);
    for (const auto& l : lines) stm << l << std::endl;
    return new MockFile(path);
  }

  ~MockFile() { std::remove(path_.c_str()); }
  const string& Path() const { return path_; }
  string DirName() const {
    auto pos = path_.find_last_of('/');
    return pos == string::npos ? "" : path_.substr(0, pos);
  }

 private:
  explicit MockFile(const string& path) : path_(path) {}
  MockFile(const MockFile&) = delete;
  MockFile& operator=(const MockFile&) = delete;
  const string path_;
};

// Mirrors the C++ facade's own shape: 4 KB stack buffer, one
// grow-and-retry via std::string on BUF_TOO_SMALL.
static string RlocFrom(rf_runfiles* rf, const char* path, const char* sr) {
  char stack[4096];
  size_t needed = 0;
  rf_rlocation_status s =
      rf_rlocation(rf, path, sr, stack, sizeof(stack), &needed);
  if (s == RF_RLOCATION_OK) return string(stack, needed);
  if (s == RF_RLOCATION_BUF_TOO_SMALL) {
    string big(needed + 1, '\0');
    s = rf_rlocation(rf, path, sr, &big[0], big.size(), &needed);
    if (s == RF_RLOCATION_OK) {
      big.resize(needed);
      return big;
    }
  }
  if (s == RF_RLOCATION_INVALID_PATH || s == RF_RLOCATION_ALLOC_FAILED) {
    ADD_FAILURE() << "rf_rlocation error " << s << " for path \"" << path
                  << "\"";
  }
  return "";
}
static string Rloc(rf_runfiles* rf, const char* path) {
  return RlocFrom(rf, path, nullptr);
}

static void ExpectEnvvars(rf_runfiles* rf, const string& expected_manifest,
                          const string& expected_dir) {
  ASSERT_EQ(rf_env_vars_count(), 3);
  EXPECT_STREQ(rf_env_var_key(0), "RUNFILES_MANIFEST_FILE");
  EXPECT_EQ(string(rf_env_var_value(rf, 0)), expected_manifest);
  EXPECT_STREQ(rf_env_var_key(1), "RUNFILES_DIR");
  EXPECT_EQ(string(rf_env_var_value(rf, 1)), expected_dir);
  EXPECT_STREQ(rf_env_var_key(2), "JAVA_RUNFILES");
  EXPECT_EQ(string(rf_env_var_value(rf, 2)), expected_dir);
}

// ==========================================================================
// Basic tests
// ==========================================================================
//
// argv0-discovery tests pass explicit empty mf/dir strings so they
// bypass the ambient RUNFILES_MANIFEST_FILE / RUNFILES_DIR that the
// Bazel test harness sets in the process env.

TEST(RunfilesCTest, CreatesFromManifestNextToBinary) {
  unique_ptr<MockFile> mf(MockFile::Create(
      "foo" LINE_AS_STRING() ".runfiles_manifest", {"a/b c/d"}));
  ASSERT_TRUE(mf != nullptr);
  string argv0 = mf->Path().substr(
      0, mf->Path().size() - string(".runfiles_manifest").size());

  char err[256] = {0};
  rf_runfiles* rf = MakeFromArgv0(argv0, err);
  ASSERT_NE(rf, nullptr) << err;
  EXPECT_STREQ(err, "");
  EXPECT_EQ(Rloc(rf, "a/b"), "c/d");
  EXPECT_EQ(Rloc(rf, "unknown"), "");  // manifest-based: empty for unknown
  ExpectEnvvars(rf, mf->Path(), "");
  rf_free(rf);
}

TEST(RunfilesCTest, CreatesFromManifestInRunfilesDir) {
  unique_ptr<MockFile> mf(MockFile::Create(
      "foo" LINE_AS_STRING() ".runfiles/MANIFEST", {"a/b c/d"}));
  ASSERT_TRUE(mf != nullptr);
  string argv0 = mf->Path().substr(
      0, mf->Path().size() - string(".runfiles/MANIFEST").size());

  char err[256] = {0};
  rf_runfiles* rf = MakeFromArgv0(argv0, err);
  ASSERT_NE(rf, nullptr) << err;
  EXPECT_EQ(Rloc(rf, "a/b"), "c/d");
  // Directory fallback for unknown key.
  EXPECT_EQ(Rloc(rf, "foo"), argv0 + ".runfiles/foo");
  ExpectEnvvars(rf, mf->Path(), argv0 + ".runfiles");
  rf_free(rf);
}

TEST(RunfilesCTest, CreatesFromExplicitPaths) {
  unique_ptr<MockFile> mf(MockFile::Create(
      "foo" LINE_AS_STRING() ".runfiles_manifest", {"a/b c/d"}));
  ASSERT_TRUE(mf != nullptr);

  char err[256] = {0};
  rf_runfiles* rf = MakeFromManifest(mf->Path(), err);
  ASSERT_NE(rf, nullptr) << err;
  EXPECT_EQ(Rloc(rf, "a/b"), "c/d");
  ExpectEnvvars(rf, mf->Path(), "");
  rf_free(rf);
}

TEST(RunfilesCTest, ManifestEscapesAreDecoded) {
  unique_ptr<MockFile> mf(MockFile::Create(
      "foo" LINE_AS_STRING() ".runfiles_manifest",
      {
          // First form (space in key): line starts with a space.
          " \\swith\\sspace foo/bar",
          // Second form: no space in key; value is verbatim (no escapes
          // are applied to the value in the second form).
          "no_space value-with-space",
          // Backslash escape \\b -> '\\'
          " k\\bwith\\bbslash x\\by",
      }));
  ASSERT_TRUE(mf != nullptr);
  char err[256] = {0};
  rf_runfiles* rf = MakeFromManifest(mf->Path(), err);
  ASSERT_NE(rf, nullptr) << err;
  EXPECT_EQ(Rloc(rf, " with space"), "foo/bar");
  EXPECT_EQ(Rloc(rf, "no_space"), "value-with-space");
  EXPECT_EQ(Rloc(rf, "k\\with\\bslash"), "x\\y");
  rf_free(rf);
}

TEST(RunfilesCTest, RejectsBadPaths) {
  unique_ptr<MockFile> mf(MockFile::Create(
      "foo" LINE_AS_STRING() ".runfiles_manifest", {"a/b c/d"}));
  ASSERT_TRUE(mf != nullptr);
  char err[256] = {0};
  rf_runfiles* rf = MakeFromManifest(mf->Path(), err);
  ASSERT_NE(rf, nullptr) << err;
  char buf[64];
  size_t needed = 0;
  const size_t cap = sizeof(buf);
  EXPECT_EQ(rf_rlocation(rf, "", nullptr, buf, cap, &needed),
            RF_RLOCATION_INVALID_PATH);
  EXPECT_EQ(rf_rlocation(rf, "../x", nullptr, buf, cap, &needed),
            RF_RLOCATION_INVALID_PATH);
  EXPECT_EQ(rf_rlocation(rf, "./x", nullptr, buf, cap, &needed),
            RF_RLOCATION_INVALID_PATH);
  EXPECT_EQ(rf_rlocation(rf, "a/../b", nullptr, buf, cap, &needed),
            RF_RLOCATION_INVALID_PATH);
  EXPECT_EQ(rf_rlocation(rf, "a/./b", nullptr, buf, cap, &needed),
            RF_RLOCATION_INVALID_PATH);
  EXPECT_EQ(rf_rlocation(rf, "a//b", nullptr, buf, cap, &needed),
            RF_RLOCATION_INVALID_PATH);
  EXPECT_EQ(rf_rlocation(rf, "a/.", nullptr, buf, cap, &needed),
            RF_RLOCATION_INVALID_PATH);
  // Backslash equivalents: the validator treats '\' as a separator on
  // ALL platforms so Windows traversal attempts like "..\\etc\\passwd"
  // are rejected instead of falling through to the directory-fallback
  // (which would resolve backslashes as parent-dir via Win32 file APIs).
  EXPECT_EQ(rf_rlocation(rf, "..\\x", nullptr, buf, cap, &needed),
            RF_RLOCATION_INVALID_PATH);
  EXPECT_EQ(rf_rlocation(rf, ".\\x", nullptr, buf, cap, &needed),
            RF_RLOCATION_INVALID_PATH);
  EXPECT_EQ(rf_rlocation(rf, "a\\..\\b", nullptr, buf, cap, &needed),
            RF_RLOCATION_INVALID_PATH);
  EXPECT_EQ(rf_rlocation(rf, "a\\.\\b", nullptr, buf, cap, &needed),
            RF_RLOCATION_INVALID_PATH);
  EXPECT_EQ(rf_rlocation(rf, "a\\\\b", nullptr, buf, cap, &needed),
            RF_RLOCATION_INVALID_PATH);
  EXPECT_EQ(rf_rlocation(rf, "a\\.", nullptr, buf, cap, &needed),
            RF_RLOCATION_INVALID_PATH);
  EXPECT_EQ(needed, 0u);
  rf_free(rf);
}

TEST(RunfilesCTest, AbsolutePassthrough) {
  unique_ptr<MockFile> mf(MockFile::Create(
      "foo" LINE_AS_STRING() ".runfiles_manifest", {"a/b c/d"}));
  ASSERT_TRUE(mf != nullptr);
  char err[256] = {0};
  rf_runfiles* rf = MakeFromManifest(mf->Path(), err);
  ASSERT_NE(rf, nullptr) << err;
  EXPECT_EQ(Rloc(rf, "/absolute/path"), "/absolute/path");
  rf_free(rf);
}

TEST(RunfilesCTest, DirectoryBasedNoManifest) {
  ASSERT_TMPDIR(tmp);
  string dir = tmp + "/foo" LINE_AS_STRING() ".runfiles";
  ASSERT_EQ(mkdir(dir.c_str(), 0777), 0);

  char err[256] = {0};
  rf_runfiles* rf =
      rf_create(nullptr, "", "", dir.c_str(), "", err, sizeof(err));
  ASSERT_NE(rf, nullptr) << err;
  EXPECT_EQ(Rloc(rf, "any/file"), dir + "/any/file");
  ExpectEnvvars(rf, "", dir);
  rf_free(rf);
  rmdir(dir.c_str());
}

TEST(RunfilesCTest, FailsWhenNothingFound) {
  char err[256] = {0};
  rf_runfiles* rf = rf_create(nullptr, "", "", "", "", err, sizeof(err));
  EXPECT_EQ(rf, nullptr);
  EXPECT_NE(strstr(err, "cannot find runfiles"), nullptr);
}

TEST(RunfilesCTest, FailsOnBadManifest) {
  unique_ptr<MockFile> mf(MockFile::Create(
      "foo" LINE_AS_STRING() ".runfiles_manifest", {"line_without_space"}));
  ASSERT_TRUE(mf != nullptr);
  char err[256] = {0};
  rf_runfiles* rf = MakeFromManifest(mf->Path(), err);
  EXPECT_EQ(rf, nullptr);
  EXPECT_NE(strstr(err, "bad runfiles manifest"), nullptr);
}

TEST(RunfilesCTest, RlocationOverridesSourceRepo) {
  // Manifest with a _repo_mapping that says: from source "src_repo", the
  // apparent name "my_module" maps to canonical "canonical_v1". No
  // mapping applies from the empty (main) source.
  ASSERT_TMPDIR(tmp);
  const string tag = std::to_string(__LINE__);
  const string mf_name = "foo" + tag + ".runfiles/MANIFEST";
  const string rmap_name = "foo" + tag + ".runfiles/_repo_mapping";
  const string rmap_path = tmp + "/" + rmap_name;

  unique_ptr<MockFile> mf(MockFile::Create(
      mf_name, {"_repo_mapping " + rmap_path,
                "canonical_v1/file resolved/canonical_v1/file"}));
  ASSERT_TRUE(mf != nullptr);
  unique_ptr<MockFile> rmap(
      MockFile::Create(rmap_name, {"src_repo,my_module,canonical_v1"}));
  ASSERT_TRUE(rmap != nullptr);

  string argv0 = mf->Path().substr(
      0, mf->Path().size() - string(".runfiles/MANIFEST").size());
  char err[256] = {0};
  rf_runfiles* rf = MakeFromArgv0(argv0, err);
  ASSERT_NE(rf, nullptr) << err;

  // With default source_repository = "", "my_module/file" does not
  // rewrite -> falls back to directory-based lookup.
  EXPECT_EQ(Rloc(rf, "my_module/file"), argv0 + ".runfiles/my_module/file");
  // With per-call source_repository = "src_repo", "my_module/file"
  // rewrites to canonical_v1/file which IS in the manifest.
  EXPECT_EQ(RlocFrom(rf, "my_module/file", "src_repo"),
            "resolved/canonical_v1/file");
  rf_free(rf);
}

// ==========================================================================
// _repo_mapping tests: parity with the C++ suite
// ==========================================================================

// Each test captures __LINE__ into `tag` -- using LINE_AS_STRING() at
// multiple sites would give different values per occurrence and break
// the manifest <-> MockFile path match.
static string BuildRmapPathIn(const string& tmp, const string& tag) {
  return tmp + "/foo" + tag + ".runfiles/_repo_mapping";
}

TEST(RunfilesCTest, RepoMappingFromMain) {
  ASSERT_TMPDIR(tmp);
  const string tag = std::to_string(__LINE__);
  const string mf_name = "foo" + tag + ".runfiles/MANIFEST";
  const string rmap_name = "foo" + tag + ".runfiles/_repo_mapping";
  const string rmap_path = BuildRmapPathIn(tmp, tag);

  unique_ptr<MockFile> mf(MockFile::Create(
      mf_name, {"_repo_mapping " + rmap_path, "config.json config/config.json",
                "protobuf+3.19.2/foo/runfile2 protobuf+3.19.2/foo/runfile2"}));
  ASSERT_TRUE(mf != nullptr);
  unique_ptr<MockFile> rmap(MockFile::Create(
      rmap_name, {",my_module,my_workspace", ",my_protobuf,protobuf+3.19.2",
                  "protobuf+3.19.2,protobuf,protobuf+3.19.2"}));
  ASSERT_TRUE(rmap != nullptr);

  string argv0 = mf->Path().substr(
      0, mf->Path().size() - string(".runfiles/MANIFEST").size());
  char err[256] = {0};
  rf_runfiles* rf = MakeFromArgv0(argv0, err);
  ASSERT_NE(rf, nullptr) << err;

  // From main workspace ("" source_repo), "my_protobuf" rewrites to
  // "protobuf+3.19.2".
  EXPECT_EQ(Rloc(rf, "my_protobuf/foo/runfile2"),
            "protobuf+3.19.2/foo/runfile2");
  // config.json is directly in the manifest.
  EXPECT_EQ(Rloc(rf, "config.json"), "config/config.json");
  rf_free(rf);
}

TEST(RunfilesCTest, RepoMappingFromOtherRepo) {
  ASSERT_TMPDIR(tmp);
  const string tag = std::to_string(__LINE__);
  const string mf_name = "foo" + tag + ".runfiles/MANIFEST";
  const string rmap_name = "foo" + tag + ".runfiles/_repo_mapping";
  const string rmap_path = BuildRmapPathIn(tmp, tag);

  unique_ptr<MockFile> mf(MockFile::Create(
      mf_name, {"_repo_mapping " + rmap_path,
                "protobuf+3.19.2/foo/runfile2 protobuf+3.19.2/foo/runfile2"}));
  ASSERT_TRUE(mf != nullptr);
  unique_ptr<MockFile> rmap(MockFile::Create(
      rmap_name, {"protobuf+3.19.2,protobuf,protobuf+3.19.2"}));
  ASSERT_TRUE(rmap != nullptr);

  string argv0 = mf->Path().substr(
      0, mf->Path().size() - string(".runfiles/MANIFEST").size());
  char err[256] = {0};
  rf_runfiles* rf = rf_create(nullptr, argv0.c_str(), "", "", "protobuf+3.19.2",
                              err, sizeof(err));
  ASSERT_NE(rf, nullptr) << err;
  EXPECT_EQ(Rloc(rf, "protobuf/foo/runfile2"), "protobuf+3.19.2/foo/runfile2");
  rf_free(rf);
}

TEST(RunfilesCTest, RepoMappingWildcardFromExtensionRepo) {
  ASSERT_TMPDIR(tmp);
  const string tag = std::to_string(__LINE__);
  const string mf_name = "foo" + tag + ".runfiles/MANIFEST";
  const string rmap_name = "foo" + tag + ".runfiles/_repo_mapping";
  const string rmap_path = BuildRmapPathIn(tmp, tag);

  unique_ptr<MockFile> mf(MockFile::Create(
      mf_name, {"_repo_mapping " + rmap_path,
                "my_module++ext+dep1/file/x resolved/dep1/file/x"}));
  ASSERT_TRUE(mf != nullptr);
  // Wildcard: for any source repo starting with "my_module++ext+",
  // apparent name "dep" maps to "my_module++ext+dep1".
  unique_ptr<MockFile> rmap(MockFile::Create(
      rmap_name, {"my_module++ext+*,dep,my_module++ext+dep1"}));
  ASSERT_TRUE(rmap != nullptr);

  string argv0 = mf->Path().substr(
      0, mf->Path().size() - string(".runfiles/MANIFEST").size());
  char err[256] = {0};
  rf_runfiles* rf = rf_create(nullptr, argv0.c_str(), "", "",
                              "my_module++ext+other_repo", err, sizeof(err));
  ASSERT_NE(rf, nullptr) << err;
  EXPECT_EQ(Rloc(rf, "dep/file/x"), "resolved/dep1/file/x");
  rf_free(rf);
}

TEST(RunfilesCTest, InvalidRepoMappingRejected) {
  ASSERT_TMPDIR(tmp);
  const string tag = std::to_string(__LINE__);
  const string mf_name = "foo" + tag + ".runfiles/MANIFEST";
  const string rmap_name = "foo" + tag + ".runfiles/_repo_mapping";
  const string rmap_path = BuildRmapPathIn(tmp, tag);

  unique_ptr<MockFile> mf(MockFile::Create(
      mf_name, {"_repo_mapping " + rmap_path, "canonical/file resolved/x"}));
  ASSERT_TRUE(mf != nullptr);
  unique_ptr<MockFile> rmap(
      MockFile::Create(rmap_name, {"only_one_comma,here"}));
  ASSERT_TRUE(rmap != nullptr);

  string argv0 = mf->Path().substr(
      0, mf->Path().size() - string(".runfiles/MANIFEST").size());
  char err[256] = {0};
  rf_runfiles* rf = MakeFromArgv0(argv0, err);
  EXPECT_EQ(rf, nullptr);
  EXPECT_NE(strstr(err, "bad repository mapping"), nullptr);
}

// Regression: an earlier impl cast const away and wrote NUL into the
// caller's path string to isolate the prefix, crashing on literals.
TEST(RunfilesCTest, PrefixFallbackDoesNotMutatePath) {
  unique_ptr<MockFile> mf(MockFile::Create(
      "foo" LINE_AS_STRING() ".runfiles_manifest", {"a resolved/dir"}));
  ASSERT_TRUE(mf != nullptr);
  string argv0 = mf->Path().substr(
      0, mf->Path().size() - string(".runfiles_manifest").size());

  char err[256] = {0};
  rf_runfiles* rf = MakeFromArgv0(argv0, err);
  ASSERT_NE(rf, nullptr) << err;

  // Pass a bona-fide string LITERAL -- must not be mutated.
  EXPECT_EQ(Rloc(rf, "a/nested/file"), "resolved/dir/nested/file");
  rf_free(rf);
}

// ==========================================================================
// Allocator hook tests
// ==========================================================================

struct AllocStats {
  int malloc_count = 0;
  int realloc_count = 0;
  int free_count_nonnull = 0;
};

static void* CountingMalloc(void* ud, size_t n) {
  static_cast<AllocStats*>(ud)->malloc_count++;
  return std::malloc(n);
}
static void* CountingRealloc(void* ud, void* p, size_t n) {
  static_cast<AllocStats*>(ud)->realloc_count++;
  return std::realloc(p, n);
}
static void CountingFree(void* ud, void* p) {
  if (p) static_cast<AllocStats*>(ud)->free_count_nonnull++;
  std::free(p);
}

TEST(RunfilesCTest, CustomAllocatorInvokedByCreateAndFree) {
  AllocStats stats;
  rf_allocator a = {CountingMalloc, CountingRealloc, CountingFree, &stats};

  unique_ptr<MockFile> mf(
      MockFile::Create("foo" LINE_AS_STRING() ".runfiles_manifest",
                       {"a/b c/d", "e/f g/h", "i/j k/l"}));
  ASSERT_TRUE(mf != nullptr);
  char err[256] = {0};
  rf_runfiles* rf =
      rf_create(&a, "", mf->Path().c_str(), "", "", err, sizeof(err));
  ASSERT_NE(rf, nullptr) << err;
  EXPECT_GT(stats.malloc_count, 0);
  EXPECT_EQ(Rloc(rf, "a/b"), "c/d");

  int free_before = stats.free_count_nonnull;
  rf_free(rf);
  // Every parsed byte + the handle itself frees through the vtable.
  EXPECT_GT(stats.free_count_nonnull, free_before);
}

TEST(RunfilesCTest, BufTooSmallReportsRequiredSize) {
  // Value "a-very-long-resolved-path-that-will-not-fit" is 42 chars.
  const string big_value = "a-very-long-resolved-path-that-will-not-fit";
  unique_ptr<MockFile> mf(MockFile::Create(
      "foo" LINE_AS_STRING() ".runfiles_manifest", {"a/b " + big_value}));
  ASSERT_TRUE(mf != nullptr);
  char err[256] = {0};
  rf_runfiles* rf = MakeFromManifest(mf->Path(), err);
  ASSERT_NE(rf, nullptr) << err;

  // Too-tiny buffer -- reports exact required size, leaves buf untouched.
  char tiny[8];
  const char sentinel = '\x7f';
  std::memset(tiny, sentinel, sizeof(tiny));
  size_t needed = 0;
  ASSERT_EQ(rf_rlocation(rf, "a/b", nullptr, tiny, sizeof(tiny), &needed),
            RF_RLOCATION_BUF_TOO_SMALL);
  EXPECT_EQ(needed, big_value.size());
  for (char c : tiny) EXPECT_EQ(c, sentinel);

  // Query-only: NULL buf, 0 cap -- pure size lookup.
  size_t query_needed = 0;
  ASSERT_EQ(rf_rlocation(rf, "a/b", nullptr, nullptr, 0, &query_needed),
            RF_RLOCATION_BUF_TOO_SMALL);
  EXPECT_EQ(query_needed, big_value.size());

  // Retry with exactly-sized buffer.
  string sized(needed + 1, '\0');
  ASSERT_EQ(rf_rlocation(rf, "a/b", nullptr, &sized[0], sized.size(), &needed),
            RF_RLOCATION_OK);
  EXPECT_EQ(needed, big_value.size());
  sized.resize(needed);
  EXPECT_EQ(sized, big_value);

  rf_free(rf);
}

TEST(RunfilesCTest, LongResolvedPathViaGrowAndRetry) {
  // 64 KB value -- larger than Rloc's 4 KB stack buffer, so this
  // exercises the std::string grow-and-retry path end-to-end.
  string big_value(64 * 1024, 'x');
  unique_ptr<MockFile> mf(
      MockFile::Create("foo" LINE_AS_STRING() ".runfiles_manifest",
                       {string("a/b ") + big_value}));
  ASSERT_TRUE(mf != nullptr);
  char err[256] = {0};
  rf_runfiles* rf = MakeFromManifest(mf->Path(), err);
  ASSERT_NE(rf, nullptr) << err;
  EXPECT_EQ(Rloc(rf, "a/b"), big_value);
  rf_free(rf);
}

// ==========================================================================
// rf_is_absolute standalone
// ==========================================================================

TEST(RunfilesCTest, IsAbsolute) {
  EXPECT_EQ(rf_is_absolute("/foo"), 1);
  EXPECT_EQ(rf_is_absolute("/foo/bar"), 1);
  EXPECT_EQ(rf_is_absolute("//host/share"),
            0);  // UNC-style not treated absolute
  EXPECT_EQ(rf_is_absolute("C:\\Windows"), 1);
  EXPECT_EQ(rf_is_absolute("c:/foo"), 1);
  EXPECT_EQ(rf_is_absolute("relative/path"), 0);
  EXPECT_EQ(rf_is_absolute(""), 0);
  EXPECT_EQ(rf_is_absolute(nullptr), 0);
}

// ==========================================================================
// rf_free(NULL) is a no-op
// ==========================================================================

TEST(RunfilesCTest, FreeNullIsNoOp) { rf_free(nullptr); }

}  // namespace
