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

#include "rules_cc/cc/runfiles/runfiles.h"

extern "C" {
#include "rules_cc/cc/runfiles/runfiles_c.h"
#include "rules_cc/cc/runfiles/runfiles_c_internal.h"
}

#include <cstdlib>
#include <functional>
#include <string>
#include <utility>
#include <vector>

namespace rules_cc {
namespace cc {
namespace runfiles {

using std::function;
using std::pair;
using std::string;
using std::vector;

namespace {

// Read an env-var as a UTF-8 std::string via the C library's
// rf_getenv_alloc, so Windows Unicode env-var handling lives in one
// place across both languages.
string GetEnv(const string& key) {
  char* raw = rf_getenv_alloc(key.c_str());
  if (!raw) return string();
  string out(raw);
  std::free(raw);
  return out;
}

// Populate the EnvVars() vector once at construction. Buffers sized to
// cover any real filesystem path (rf_paths_from itself caps at 4096;
// 8192 gives headroom for the JAVA_RUNFILES / RUNFILES_DIR keys).
vector<pair<string, string> > BuildEnvVars(rf_runfiles* rf) {
  int n = rf_env_vars_count(rf);
  vector<pair<string, string> > out;
  out.reserve(static_cast<size_t>(n));
  char k[128];
  char v[8192];
  for (int i = 0; i < n; i++) {
    if (rf_env_var(rf, i, k, sizeof(k), v, sizeof(v))) {
      out.emplace_back(k, v);
    }
  }
  return out;
}

// Bridge the std::function predicates from TestOnly_PathsFrom down to
// the C #rf_predicate function-pointer shape. Not on the production
// code path.
using PredicatePair =
    pair<function<bool(const string&)>, function<bool(const string&)> >;
int PredicateTrampolineIsMf(void* userdata, const char* path) {
  auto* p = static_cast<PredicatePair*>(userdata);
  return p->first(path) ? 1 : 0;
}
int PredicateTrampolineIsDir(void* userdata, const char* path) {
  auto* p = static_cast<PredicatePair*>(userdata);
  return p->second(path) ? 1 : 0;
}

}  // namespace

Runfiles::~Runfiles() { rf_free(handle_); }

// Full-parameter constructor — every other Create overload eventually
// forwards here.
Runfiles* Runfiles::Create(const string& argv0,
                           const string& runfiles_manifest_file,
                           const string& runfiles_dir,
                           const string& source_repository, string* error) {
  char err[512] = {0};
  rf_runfiles* handle = rf_create_ex(
      /*alloc=*/nullptr, argv0.c_str(), runfiles_manifest_file.c_str(),
      runfiles_dir.c_str(), source_repository.c_str(), err, sizeof(err));
  if (!handle) {
    if (error) *error = err;
    return nullptr;
  }
  return new Runfiles(handle, source_repository, BuildEnvVars(handle));
}

Runfiles* Runfiles::Create(const string& argv0,
                           const string& runfiles_manifest_file,
                           const string& runfiles_dir, string* error) {
  return Create(argv0, runfiles_manifest_file, runfiles_dir, "", error);
}

Runfiles* Runfiles::Create(const string& argv0, const string& source_repository,
                           string* error) {
  return Create(argv0, GetEnv("RUNFILES_MANIFEST_FILE"), GetEnv("RUNFILES_DIR"),
                source_repository, error);
}

Runfiles* Runfiles::Create(const string& argv0, string* error) {
  return Create(argv0, "", error);
}

Runfiles* Runfiles::CreateForTest(const string& source_repository,
                                  string* error) {
  char err[512] = {0};
  rf_runfiles* handle = rf_create_for_test_ex(
      /*alloc=*/nullptr, source_repository.c_str(), err, sizeof(err));
  if (!handle) {
    if (error) *error = err;
    return nullptr;
  }
  return new Runfiles(handle, source_repository, BuildEnvVars(handle));
}

Runfiles* Runfiles::CreateForTest(string* error) {
  return CreateForTest("", error);
}

string Runfiles::Rlocation(const string& path) const {
  return Rlocation(path, source_repository_);
}

string Runfiles::Rlocation(const string& path,
                           const string& source_repo) const {
  // 8 KB output buffer covers any real filesystem path. rf_rlocation
  // returns <=0 for invalid paths, unknown runfiles, or buffer-too-
  // small; all of those legitimately produce the empty string on the
  // C++ side.
  char buf[8192];
  int n = rf_rlocation_from(handle_, path.c_str(), source_repo.c_str(), buf,
                            sizeof(buf));
  if (n <= 0) return string();
  return string(buf, static_cast<size_t>(n));
}

namespace testing {

bool TestOnly_PathsFrom(const string& argv0, string mf, string dir,
                        function<bool(const string&)> is_runfiles_manifest,
                        function<bool(const string&)> is_runfiles_directory,
                        string* out_manifest, string* out_directory) {
  PredicatePair ctx(std::move(is_runfiles_manifest),
                    std::move(is_runfiles_directory));
  char mf_buf[4096] = {0};
  char dir_buf[4096] = {0};
  int ok =
      rf_paths_from(argv0.c_str(), mf.c_str(), dir.c_str(),
                    &PredicateTrampolineIsMf, &PredicateTrampolineIsDir, &ctx,
                    mf_buf, sizeof(mf_buf), dir_buf, sizeof(dir_buf));
  *out_manifest = mf_buf;
  *out_directory = dir_buf;
  return ok != 0;
}

bool TestOnly_IsAbsolute(const string& path) {
  return rf_is_absolute(path.c_str()) != 0;
}

}  // namespace testing
}  // namespace runfiles
}  // namespace cc
}  // namespace rules_cc
