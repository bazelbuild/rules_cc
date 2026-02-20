#include "binary_helper.h"
#include "public.h"

#if __has_include("private.h")
#error "private.h should not be on the include path"
#endif


int main() {
  return foo() + helper();
}
