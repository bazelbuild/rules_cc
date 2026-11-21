// Copyright 2026 The Bazel Authors. All rights reserved.
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

// Includes <features.h> on glibc.
#include <string.h>

// GLIBC_AT_LEAST_MINOR is the minor version of the most specific matching
// //cc/libc:glibc_at_least_2.<minor> setting, if any.
#ifdef GLIBC_AT_LEAST_MINOR
#if !defined(__GLIBC__) || __GLIBC__ != 2 || \
    __GLIBC_MINOR__ < GLIBC_AT_LEAST_MINOR
#error "The C++ toolchain reports a newer glibc version than its headers"
#endif
#endif

int main() { return 0; }
