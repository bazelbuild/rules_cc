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

#if defined(__clang__)
constexpr bool kIsClang = true;
#else
constexpr bool kIsClang = false;
#endif

// clang-cl emulates the MSVC command line and ABI, so it defines _MSC_VER as
// well as __clang__. cl.exe defines only _MSC_VER.
#if defined(_MSC_VER)
constexpr bool kIsMsvcCompatible = true;
#else
constexpr bool kIsMsvcCompatible = false;
#endif

// Cross-check the declared compiler against what really compiled this file, so
// a toolchain cannot claim one compiler while running another. This is what
// catches USE_CLANG_CL=1 swapping the toolchain over to clang-cl while it
// still declares itself msvc-cl.
//
// Stated as implications keyed off the declared name rather than deriving an
// expected name from the macros: that way only the two labels this repo emits
// are constrained, and any other value -- a third-party toolchain's, or one
// that does not match a //cc/compiler config_setting at all -- is left alone
// instead of failing the build.
static_assert(!StrEq(kDeclaredCompiler, "msvc-cl") || !kIsClang,
              "Toolchain declares msvc-cl, but clang compiled this file.");
static_assert(!StrEq(kDeclaredCompiler, "clang-cl") ||
                  (kIsClang && kIsMsvcCompatible),
              "Toolchain declares clang-cl, but clang in MSVC-compatible mode "
              "is not what compiled this file.");

}  // namespace

#endif  // COMPILER

int main() {
  std::cout << "Hello, " << TO_STRING(COMPILER) << "!" << std::endl;
}
