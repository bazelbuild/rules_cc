#include <iostream>

#include "examples/test_cc_shared_library/a_suffix.h"

int main() {
  std::cout << "hello " << a_suffix() << std::endl;
  return 0;
}
