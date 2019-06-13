#include "a.h"

#include <string>

#include "c.h"
#include "d.h"

std::string a() { return "-a" + c() + d(); }
