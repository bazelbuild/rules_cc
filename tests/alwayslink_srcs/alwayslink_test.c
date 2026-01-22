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

#include <stdio.h>

#include "tests/alwayslink_srcs/registered.h"

int main(void) {
  // If alwayslink worked correctly, the registerer library should have been
  // linked even though nothing directly references its symbols. The static
  // constructor should have called set_registered().
  if (!was_registered()) {
    fprintf(stderr, "FAILED: alwayslink did not work - static constructor was not executed\n");
    return 1;
  }
  printf("PASSED: alwayslink worked - static constructor was executed\n");
  return 0;
}
