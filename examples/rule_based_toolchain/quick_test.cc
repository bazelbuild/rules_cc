#include <gtest/gtest.h>

#include "dynamic_answer.h"
#include "static_answer.h"

TEST(Static, ProperlyLinked) {
  EXPECT_EQ(static_answer(), 42);
}

TEST(Dynamic, ProperlyLinked) {
  EXPECT_EQ(dynamic_answer(), 24);
}
