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

#include "tests/protobuf/intermediate_proto_lib.h"

#include <string>

#include "tests/protobuf/simple.pb.h"

namespace tests::protobuf {

int GetTestProtoValue() {
    SimpleMessage simple_message;
    simple_message.set_my_num(kExpectedValue);

    // Ensure serialization methods are linked in.
    std::string buf;
    simple_message.SerializeToString(&buf);
    simple_message.ParseFromString(buf);

    return simple_message.my_num();
}

}  // namespace tests::protobuf
