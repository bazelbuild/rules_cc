// Copyright 2023 The Bazel Authors. All rights reserved.
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

#include <iostream>

#define STRINGIFY(x) #x
#define TO_STRING(x) STRINGIFY(x)

#ifdef COMPILER

namespace {

constexpr bool StrEq(const char* a, const char* b) {
  return *a == *b && (*a == '\0' || StrEq(a + 1, b + 1));
}

// The compiler //cc/compiler:compiler reports, i.e. the `compiler` attribute
// of the resolved cc_toolchain_config.
constexpr const char* kDeclaredCompiler = TO_STRING(COMPILER);

// Cross-check that against what is really compiling this file, so a toolchain
// cannot claim one compiler while running another. Only the MSVC-compatible
// drivers are checked: clang-cl emulates the MSVC command line and so defines
// _MSC_VER as well as __clang__, while cl.exe defines only _MSC_VER. The
// gcc/clang/msys/mingw cases are not distinguishable by predefined macros
// alone and are left alone.
//
// This is what catches USE_CLANG_CL=1 reconfiguring the toolchain to run
// clang-cl while it still declares itself msvc-cl.
#if defined(_MSC_VER)
#if defined(__clang__)
static_assert(StrEq(kDeclaredCompiler, "clang-cl"),
              "Compiled by clang-cl, but the toolchain declares a different "
              "compiler.");
#else
static_assert(StrEq(kDeclaredCompiler, "msvc-cl"),
              "Compiled by MSVC cl.exe, but the toolchain declares a "
              "different compiler.");
#endif
#endif

}  // namespace

#endif  // COMPILER

int main() {
  std::cout << "Hello, " << TO_STRING(COMPILER) << "!" << std::endl;
}
