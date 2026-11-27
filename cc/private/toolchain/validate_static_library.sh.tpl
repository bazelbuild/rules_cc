#!/bin/sh
#
# Copyright 2023 The Bazel Authors. All rights reserved.
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
set -eu

# Find all duplicate symbols in the given static library:
# 1. Use nm to list all global symbols in the library in POSIX format:
#    libstatic.a[my_object.o]: my_function T 1234 abcd
# 2. Use sed to transform the output to a format that can be sorted by symbol
#    name and is readable by humans:
#    my_object.o: T my_function
#    By using the `t` and `d` commands, lines for symbols of type U (undefined)
#    as well as V and W (weak) and their local lowercase variants are removed.
# 3. Use sort to sort the lines by symbol name.
# 4. Use awk to only keep the lines corresponding to duplicate symbols, that
#    is, those whose symbol name matches the line before or after.  This is
#    what uniq -D -f 2 does, but -D is not in POSIX and OpenBSD does not have
#    it.
# 5. Use c++filt to demangle the symbol names.
#    c++filt is applied to the duplicated symbols instead of using the -C flag
#    of nm because it is not in POSIX and demangled names may not be unique
#    (https://gcc.gnu.org/bugzilla/show_bug.cgi?id=35201).
#
# Each step runs on its own and keeps its output in a variable, so that set -e
# sees any one of them fail; not every sh has pipefail.
SYMBOLS=$("%{nm}" -A -g -P %{nm_extra_args} "$1")
SYMBOLS=$(printf '%s\n' "$SYMBOLS" |
  sed -E -e 's/.*\[([^][]+)\]: (.+) ([A-TX-Z]) [a-f0-9]+ [a-f0-9]+/\1: \3 \2/g' -e t -e d)
SYMBOLS=$(printf '%s\n' "$SYMBOLS" | LC_ALL=C sort -k 3)
DUPLICATE_SYMBOLS=$(printf '%s\n' "$SYMBOLS" | LC_ALL=C awk '
  { name = $0; sub(/^[^ ]* [^ ]* /, "", name) }
  NR > 1 && name == prev_name { if (!shown) print prev; print; shown = 1; next }
  { shown = 0; prev_name = name; prev = $0 }')
if [ -n "$DUPLICATE_SYMBOLS" ]; then
  DUPLICATE_SYMBOLS=$(printf '%s\n' "$DUPLICATE_SYMBOLS" | "%{c++filt}")
fi
if [ -n "$DUPLICATE_SYMBOLS" ]; then
  >&2 echo "Duplicate symbols found in $1:"
  >&2 echo "$DUPLICATE_SYMBOLS"
  exit 1
else
  touch "$2"
fi
