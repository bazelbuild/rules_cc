# Copyright 2026 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""The C and C++ language standard feature names provided by rules_cc.

Feature names match the value accepted by the GCC/Clang `-std=` flag. The
MSVC dictionaries map the subset of those names that MSVC and clang-cl
understand onto the corresponding `/std:` flag.
"""

# C standards, as understood by `-std=`.
C_STANDARDS = [
    "c89",
    "c99",
    "c11",
    "c17",
    "c23",
    "gnu89",
    "gnu99",
    "gnu11",
    "gnu17",
    "gnu23",
]

# C++ standards, as understood by `-std=`.
CPP_STANDARDS = [
    "c++98",
    "c++11",
    "c++14",
    "c++17",
    "c++20",
    "c++23",
    "c++26",
    "gnu++98",
    "gnu++11",
    "gnu++14",
    "gnu++17",
    "gnu++20",
    "gnu++23",
    "gnu++26",
]

# C standards available on MSVC and clang-cl, mapped to the `/std:` flag.
# MSVC has no mode for C89 or C99, and no GNU dialects. C23 maps to the
# "latest" draft mode, which is the closest MSVC offers.
MSVC_C_STANDARDS = {
    "c11": "/std:c11",
    "c17": "/std:c17",
    "c23": "/std:clatest",
}

# C++ standards available on MSVC and clang-cl, mapped to the `/std:` flag.
# MSVC has no mode older than C++14 and no GNU dialects. C++23 and C++26 both
# map to the "latest" draft mode, which is the closest MSVC offers.
MSVC_CPP_STANDARDS = {
    "c++14": "/std:c++14",
    "c++17": "/std:c++17",
    "c++20": "/std:c++20",
    "c++23": "/std:c++latest",
    "c++26": "/std:c++latest",
}
