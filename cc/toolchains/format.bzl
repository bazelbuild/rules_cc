# Copyright 2024 The Bazel Authors. All rights reserved.
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
"""Functions to format arguments for the cc toolchain"""

def format_arg(format, value = None):
    """Generate metadata to format a variable with a given value.

    Args:
      format: (str) The format string
      value: (Optional[Label]) The variable to format. Any is used because it can
        be any representation of a variable.
    Returns:
      A struct corresponding to the formatted variable.
    """
    return struct(format_type = "format_arg", format = format, value = value)
