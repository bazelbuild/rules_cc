#include "binary_helper.h"
#include "public.h"

#if __has_include("private.h")
#error "private.h should not be on the include path"
#endif


int main() {
  if (foo() + helper() == 42) {
    return 0;
  } else {
    return 1;
  }
}
