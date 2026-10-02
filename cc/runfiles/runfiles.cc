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

// @param key ASCII environment variable name.
// @return The variable's value, or "" if unset.
string GetEnv(const string& key) {
  char* raw = rf_getenv_alloc(/*alloc=*/nullptr, key.c_str());
  if (!raw) return string();
  string out(raw);
  std::free(raw);
  return out;
}

// @param rf Handle whose paths to copy.
// @return The key/value pairs reported by rf_env_var_key / rf_env_var_value.
vector<pair<string, string> > BuildEnvVars(rf_runfiles* rf) {
  int n = rf_env_vars_count();
  vector<pair<string, string> > out;
  out.reserve(static_cast<size_t>(n));
  for (int i = 0; i < n; i++) {
    const char* k = rf_env_var_key(i);
    const char* v = rf_env_var_value(rf, i);
    if (k && v) out.emplace_back(k, v);
  }
  return out;
}

// (is_runfiles_manifest, is_runfiles_directory) passed through
// rf_paths_from's userdata.
using PredicatePair =
    pair<function<bool(const string&)>, function<bool(const string&)> >;
// rf_predicate forwarding to PredicatePair::first.
//
// @param userdata A PredicatePair*.
// @param path Path to test.
// @return 1 if the predicate returns true, else 0.
int PredicateTrampolineIsMf(void* userdata, const char* path) {
  auto* p = static_cast<PredicatePair*>(userdata);
  return p->first(path) ? 1 : 0;
}
// rf_predicate forwarding to PredicatePair::second.
//
// @param userdata A PredicatePair*.
// @param path Path to test.
// @return 1 if the predicate returns true, else 0.
int PredicateTrampolineIsDir(void* userdata, const char* path) {
  auto* p = static_cast<PredicatePair*>(userdata);
  return p->second(path) ? 1 : 0;
}

}  // namespace

Runfiles::~Runfiles() = default;

Runfiles* Runfiles::Create(const string& argv0,
                           const string& runfiles_manifest_file,
                           const string& runfiles_dir,
                           const string& source_repository, string* error) {
  char err[512] = {0};
  rf_runfiles* handle = rf_create(
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
  rf_runfiles* handle = rf_create_for_test(
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
  string buf;
  buf.resize(4096);
  size_t needed = 0;
  rf_rlocation_status s =
      rf_rlocation(handle_.get(), path.c_str(), source_repo.c_str(), &buf[0],
                   buf.size(), &needed);
  if (s == RF_RLOCATION_BUF_TOO_SMALL) {
    // The first call reported the exact size, so one retry suffices.
    buf.resize(needed + 1);
    s = rf_rlocation(handle_.get(), path.c_str(), source_repo.c_str(), &buf[0],
                     buf.size(), &needed);
  }
  if (s != RF_RLOCATION_OK) return string();
  buf.resize(needed);
  return buf;
}

namespace testing {

bool TestOnly_PathsFrom(const string& argv0, string mf, string dir,
                        function<bool(const string&)> is_runfiles_manifest,
                        function<bool(const string&)> is_runfiles_directory,
                        string* out_manifest, string* out_directory) {
  PredicatePair ctx(std::move(is_runfiles_manifest),
                    std::move(is_runfiles_directory));
  char* mf_out = nullptr;
  char* dir_out = nullptr;
  int ok = rf_paths_from(argv0.c_str(), mf.c_str(), dir.c_str(),
                         &PredicateTrampolineIsMf, &PredicateTrampolineIsDir,
                         &ctx, /*alloc=*/nullptr, &mf_out, &dir_out);
  out_manifest->assign(mf_out ? mf_out : "");
  out_directory->assign(dir_out ? dir_out : "");
  std::free(mf_out);
  std::free(dir_out);
  return ok != 0;
}

bool TestOnly_IsAbsolute(const string& path) {
  return rf_is_absolute(path.c_str()) != 0;
}

}  // namespace testing
}  // namespace runfiles
}  // namespace cc
}  // namespace rules_cc
