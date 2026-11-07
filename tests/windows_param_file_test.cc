#include <cassert>
#include <cstring>

int main() {
  assert(std::strcmp(GREETING, "Hello world!") == 0);
  assert(std::strcmp(LOCAL_GREETING, "Hello local world!") == 0);
  return 0;
}
