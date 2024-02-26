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
"""."""

def get_action_type(args_list, action_type):
    """Returns the corresponding entry in ArgsListInfo.by_action.

    Args:
        args_list: (ArgsListInfo) The args list to look through
        action_type: (ActionTypeInfo) The action type to look up.
    Returns:
        The information corresponding to this action type.

    """
    for args in args_list.by_action:
        if args.action == action_type:
            return args

    return struct(action = action_type, args = tuple(), files = depset([]))
