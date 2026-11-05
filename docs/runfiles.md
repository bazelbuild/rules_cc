# Runfiles

`rules_cc` provides two libraries for looking up runfiles from Bazel-built
programs. The C++ library is a wrapper over the C library, so both behave
identically.

| Library | Bazel target                        | Include                              |
|---------|-------------------------------------|--------------------------------------|
| C++     | `@rules_cc//cc/runfiles:runfiles`   | `rules_cc/cc/runfiles/runfiles.h`    |
| C       | `@rules_cc//cc/runfiles:runfiles_c` | `rules_cc/cc/runfiles/runfiles_c.h`  |

Use the C++ library from C++ code. Use the C library from C code, when you
cannot link the C++ standard library, or when you need a custom allocator.

## C++ library

```python
cc_binary(
    name = "my_binary",
    srcs = ["my_binary.cc"],
    deps = ["@rules_cc//cc/runfiles"],
)
```

```cpp
#include "rules_cc/cc/runfiles/runfiles.h"

#include <iostream>
#include <memory>
#include <string>

using rules_cc::cc::runfiles::Runfiles;

int main(int argc, char** argv) {
  std::string error;
  std::unique_ptr<Runfiles> runfiles(
      Runfiles::Create(argv[0], BAZEL_CURRENT_REPOSITORY, &error));
  if (!runfiles) {
    std::cerr << error << std::endl;
    return 1;
  }

  // Empty if the runfile is unknown. The file may not exist even if the
  // path is non-empty.
  std::string path = runfiles->Rlocation("my_workspace/path/to/data.txt");
}
```

`BAZEL_CURRENT_REPOSITORY` is defined for every target that depends on the
runfiles library. It names the canonical repository containing the target
and is the value `_repo_mapping` rewrites are resolved against.

In a `cc_test`, use `Runfiles::CreateForTest`, which reads
`RUNFILES_MANIFEST_FILE` and `TEST_SRCDIR` instead of `RUNFILES_DIR` and
`argv[0]`:

```cpp
std::unique_ptr<Runfiles> r(
    Runfiles::CreateForTest(BAZEL_CURRENT_REPOSITORY, &error));
```

The full API is in [`cc/runfiles/runfiles.h`](../cc/runfiles/runfiles.h):

- `Runfiles::Create(argv0, [manifest, dir,] [source_repo,] error)` and
  `Runfiles::CreateForTest([source_repo,] error)`.
- `Rlocation(path)` and `Rlocation(path, source_repo)`.
- `WithSourceRepository(source_repo)` returns an instance that shares the
  parsed data but uses a different default source repository.
- `EnvVars()` returns the environment variables a subprocess needs in order
  to find the same runfiles.

## C library

```python
cc_binary(
    name = "my_binary",
    srcs = ["my_binary.c"],
    deps = ["@rules_cc//cc/runfiles:runfiles_c"],
)
```

```c
#include "rules_cc/cc/runfiles/runfiles_c.h"

#include <stdio.h>

int main(int argc, char** argv) {
  char err[256];
  rf_runfiles* rf = rf_create(/*alloc=*/NULL, argv[0], /*manifest=*/"",
                              /*dir=*/"", /*source_repo=*/"", err,
                              sizeof(err));
  if (!rf) {
    fputs(err, stderr);
    return 1;
  }

  char buf[4096];
  size_t needed = 0;
  rf_rlocation_status s = rf_rlocation(rf, "my_workspace/path/to/data.txt",
                                       /*source_repository=*/NULL, buf,
                                       sizeof(buf), &needed);
  switch (s) {
    case RF_RLOCATION_OK:
      /* buf holds the NUL-terminated path; needed == strlen(buf). */
      break;
    case RF_RLOCATION_BUF_TOO_SMALL:
      /* buf is untouched; retry with a buffer of needed + 1 bytes. */
      break;
    case RF_RLOCATION_NOT_FOUND:
    case RF_RLOCATION_INVALID_PATH:
    case RF_RLOCATION_ALLOC_FAILED:
      break;
  }

  rf_free(rf);
  return 0;
}
```

`rf_create` does not read environment variables. Pass the values of
`RUNFILES_MANIFEST_FILE` and `RUNFILES_DIR` yourself, or `""` to discover
the runfiles next to `argv[0]`. In a `cc_test`, use `rf_create_for_test`,
which reads `RUNFILES_MANIFEST_FILE` and `TEST_SRCDIR`.

`rf_rlocation` writes into a caller-owned buffer. On
`RF_RLOCATION_BUF_TOO_SMALL` the buffer is untouched and `*needed` holds
the required length excluding the NUL terminator. Passing `buf = NULL` and
`buf_cap = 0` queries the size without writing.

### Custom allocator

All of a handle's internal allocations go through the `rf_allocator`
passed to `rf_create*`; `NULL` selects libc. The struct is copied into the
handle, but `userdata` is held by pointer and must outlive the handle. File
I/O still uses the C standard library.

```c
static void* my_malloc(void* ud, size_t n)           { /* … */ }
static void* my_realloc(void* ud, void* p, size_t n) { /* … */ }
static void  my_free(void* ud, void* p)              { /* … */ }

rf_allocator my_alloc = {my_malloc, my_realloc, my_free, /*userdata=*/NULL};
rf_runfiles* rf = rf_create(&my_alloc, argv[0], "", "", "", err, sizeof(err));
```

### Subprocess environment

```c
int n = rf_env_vars_count();
for (int i = 0; i < n; ++i) {
  setenv(rf_env_var_key(i), rf_env_var_value(rf, i), /*overwrite=*/1);
}
```

Keys are static strings. Values are owned by the handle and valid until
`rf_free`. The variables are `RUNFILES_MANIFEST_FILE`, `RUNFILES_DIR`, and
`JAVA_RUNFILES` (same value as `RUNFILES_DIR`).

The full API is in [`cc/runfiles/runfiles_c.h`](../cc/runfiles/runfiles_c.h).

## Behavior

### Discovery

Both libraries try, in order:

1. The explicit manifest and directory arguments.
2. `<argv0>.runfiles/MANIFEST` with `<argv0>.runfiles`, then
   `<argv0>.runfiles_manifest`.
3. If only the directory was found, `<dir>/MANIFEST` and `<dir>_manifest`.
4. If only the manifest was found, the directory obtained by stripping its
   `_manifest` or `/MANIFEST` suffix.

Creation succeeds if at least one of the manifest and directory was found.
Without a directory, unknown runfiles resolve to `""` or
`RF_RLOCATION_NOT_FOUND`. With a directory, they resolve to
`<directory>/<path>`, which may not exist.

### `_repo_mapping`

Bzlmod builds emit a `_repo_mapping` runfile that maps apparent repository
names to canonical ones. Both libraries read it at creation and apply it in
`Rlocation` to a path `apparent/rest`:

1. If an entry exists for `(apparent, source_repo)`, look up
   `<canonical>/rest`.
2. Otherwise, if the largest entry not greater than
   `(apparent, source_repo)` is for `apparent` with a source repository
   ending in `*`, and `source_repo` starts with the part before the `*`,
   look up `<canonical>/rest`.
3. Otherwise, look up the path as-is.

`source_repo` is the default given at creation or the per-call override.

### Path validation

`Rlocation` rejects empty paths, paths starting with `../` or `./`, paths
containing `/..`, `/./`, or `//`, and paths ending in `/.`. Backslashes are
treated as separators for this check on every platform. Absolute paths
(`/foo`, `C:\foo`) are returned unchanged.

### Manifest format

One entry per line:

```text
raw_key raw_value                # first char is not space; no escaping
 escaped_key escaped_value       # first char is space; both fields escaped
```

In the escaped form, `\s` is a space, `\n` a newline, and `\b` a
backslash. Any other backslash sequence is kept as-is. A blank line ends
the manifest.

### Lifetime and thread safety

Each `Create` or `rf_create*` call parses the manifest and `_repo_mapping`
and returns an instance that owns its data; there is no process-wide cache.
Instances are independent. A single instance may be used concurrently for
lookups but must not be destroyed while a lookup is in flight.
