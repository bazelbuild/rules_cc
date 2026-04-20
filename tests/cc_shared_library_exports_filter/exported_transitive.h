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

#ifdef _WIN32
#if defined(EXPORTED_TRANSITIVE_EXPORTS)
#define EXPORTED_TRANSITIVE_API __declspec(dllexport)
#else
#define EXPORTED_TRANSITIVE_API __declspec(dllimport)
#endif
#else
#define EXPORTED_TRANSITIVE_API
#endif

EXPORTED_TRANSITIVE_API int exported_transitive();
