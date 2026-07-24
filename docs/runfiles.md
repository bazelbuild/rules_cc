# Runfiles

`rules_cc` provides two source-level libraries for looking up runfiles from
Bazel-built C and C++ programs. They implement the same algorithm and stay
behavior-parity; they differ only in language surface and allocation
policy.

| Library  | Bazel target                         | Include                              |
|----------|--------------------------------------|--------------------------------------|
| C++      | `@rules_cc//cc/runfiles:runfiles`    | `rules_cc/cc/runfiles/runfiles.h`    |
| Pure C   | `@rules_cc//cc/runfiles:runfiles_c`  | `rules_cc/cc/runfiles/runfiles_c.h`  |

The C library exposes a pluggable allocator (`rf_set_allocator`) so C
consumers can route every heap allocation through their own memory
backend. The C++ library uses `std::allocator` exclusively — it never
invokes the C-side allocator hook.

## Choosing between them

Use the C++ library from any C++ source. It's the default and lets you
work with `std::string` / `std::map` / `std::unique_ptr` directly.

Use the pure-C library when you need to look up runfiles from C code, or
when you cannot link libstdc++, or when you want to control the runfiles
library's allocation. Typical cases: embedded programs, foreign-function
bindings (Rust, Go, Fortran, …), and toolchains that ship their own C
runtime.

Mixing both in the same process is safe — each library keeps its own
per-process cache of parsed data. The manifest is parsed at most twice
(once per language), and neither library ever holds memory owned by the
other's allocator.

## C++ library

### Depend on it

```python
cc_binary(
    name = "my_binary",
    srcs = ["my_binary.cc"],
    deps = ["@rules_cc//cc/runfiles"],
)
```

### Look up a runfile

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

  std::string path = runfiles->Rlocation("my_workspace/path/to/data.txt");
  // `path` is empty if the runfile is unknown; the file may or may not
  // exist on disk regardless — callers should check.
}
```

`BAZEL_CURRENT_REPOSITORY` is defined for every target that depends on
`//cc/runfiles:runfiles`; it names the repo that contains the calling
target and is required for `_repo_mapping` rewrites (see below) to
resolve correctly.

### In a `cc_test`

Use `Runfiles::CreateForTest` instead of `Runfiles::Create` — it reads
`RUNFILES_MANIFEST_FILE` and `TEST_SRCDIR` (set by `bazel test`) instead
of doing argv0-based discovery.

```cpp
std::unique_ptr<Runfiles> r(
    Runfiles::CreateForTest(BAZEL_CURRENT_REPOSITORY, &error));
```

### API

Full API in
[`cc/runfiles/runfiles.h`](../cc/runfiles/runfiles.h). The public
surface is:

- `Runfiles::Create(argv0, [manifest, dir,] [source_repo,] error)` and
  `Runfiles::CreateForTest([source_repo,] error)` — construction.
- `std::string Rlocation(path)` /
  `std::string Rlocation(path, source_repo)` — path lookup.
- `const std::vector<std::pair<std::string, std::string>>& EnvVars() const` —
  subprocess env.
- `std::unique_ptr<Runfiles> WithSourceRepository(source_repo)` —
  returns a new handle that shares parsed data with `this` but overrides
  the default source repository.

`Create` returns a fresh `Runfiles*` per call (transfer ownership to the
caller — wrap in `std::unique_ptr` or `delete` yourself), but the
underlying parsed manifest is shared via a process-wide
`std::shared_ptr<const RunfilesData>` cache keyed on the resolved
`(manifest, directory)` pair. This means: repeated `Create` calls with
the same effective configuration do not re-parse the manifest.
`WithSourceRepository` is O(1) — a `shared_ptr` copy, not a data copy.

## Pure C library

### Depend on it

```python
cc_binary(
    name = "my_binary",
    srcs = ["my_binary.c"],
    deps = ["@rules_cc//cc/runfiles:runfiles_c"],
)
```

### Look up a runfile

```c
#include "rules_cc/cc/runfiles/runfiles_c.h"

#include <stdio.h>

int main(int argc, char** argv) {
  char err[256];
  rf_runfiles* rf = rf_create(argv[0], err, sizeof(err));
  if (!rf) {
    fputs(err, stderr);
    return 1;
  }

  char path[4096];
  int n = rf_rlocation(rf, "my_workspace/path/to/data.txt", path,
                       sizeof(path));
  if (n > 0) {
    /* path is the resolved runfile, `n` bytes long (excluding NUL). */
  } else if (n == 0) {
    /* Well-formed path but the runfile is unknown. */
  } else {
    /* -1: NULL arg, invalid path, or result buffer too small. */
  }

  rf_free(rf);
  return 0;
}
```

`rf_rlocation` writes into a caller-provided buffer. Passing a
too-small buffer returns `-1`; retry with a larger one if needed.
`PATH_MAX` (typically 4096) is a safe upper bound for real runfiles
paths.

### Custom allocator

Every heap allocation the C library performs — long-lived handle state,
the shared parsed data, the cache-slot key strings, and the parser's
transient scratch buffers — routes through a pluggable allocator
vtable. Install it once at process start, BEFORE the first `rf_create*`
call:

```c
static void* my_malloc(void* ud, size_t n)           { /* … */ }
static void* my_realloc(void* ud, void* p, size_t n) { /* … */ }
static void  my_free(void* ud, void* p)              { /* … */ }

rf_allocator alloc = {my_malloc, my_realloc, my_free, /*userdata=*/NULL};
rf_set_allocator(&alloc);
```

- `rf_set_allocator(NULL)` restores libc `malloc`/`realloc`/`free`.
- The setter is process-wide. It IS safe to call concurrently with
  `rf_create*` (both sides take the library mutex), but if you race
  them the newly-created handle uses whichever allocator the write-side
  lock happened to publish first. There is no data race — the storage
  a handle allocates and the storage `rf_free` releases always come
  from the same allocator — but you cannot predict which allocator a
  concurrent create observes.
- Each handle *remembers* the allocator that was active when it was
  built. If you install allocator A, create a handle, then install
  allocator B, freeing the first handle still routes through allocator
  A. This means allocator userdata must outlive the last handle that
  was created under it.
- File I/O (`fopen`, `fclose`, `fgets`) is inherent to libc and cannot
  be redirected through the allocator hook.

### API

Full API in
[`cc/runfiles/runfiles_c.h`](../cc/runfiles/runfiles_c.h). The public
surface is:

- `rf_create(argv0, err, err_len)` /
  `rf_create_for_test(err, err_len)` — env-var-based construction.
- `rf_create_ex(argv0, manifest, dir, source_repo, err, err_len)` /
  `rf_create_for_test_ex(source_repo, err, err_len)` — explicit paths
  and source repo.
- `rf_with_source_repository(rf, source_repo)` — clone with a different
  default source repo, shared data.
- `rf_rlocation(rf, path, buf, buf_len)` /
  `rf_rlocation_from(rf, path, source_repo, buf, buf_len)` — path
  lookup.
- `rf_env_vars_count(rf)` + `rf_env_var(rf, i, k, kl, v, vl)` —
  subprocess env.
- `rf_free(rf)` — destructor. No-op on `NULL`.
- `rf_set_allocator(alloc)` — install/clear the global allocator.
- `rf_is_absolute(path)` — utility; matches the algorithm the library
  uses internally.

## Discovery, path lookup, and repo mapping

Both libraries implement identical algorithms. This section describes
what they do.

### Path discovery order

Both libraries try, in order:

1. Explicit `manifest`/`directory` arguments (if you called
   `Runfiles::Create(argv0, mf, dir, …)` or `rf_create_ex(argv0, mf,
   dir, …)`).
2. Environment variables — `RUNFILES_MANIFEST_FILE`, `RUNFILES_DIR`
   (for `Create`) or `TEST_SRCDIR` (for `CreateForTest`).
3. Argv0-based fallback:
   `<argv0>.runfiles/MANIFEST` + `<argv0>.runfiles/`, then
   `<argv0>.runfiles_manifest`.
4. If a manifest was found but no directory, derive the directory by
   stripping the `_manifest` or `/MANIFEST` suffix.

The library succeeds if at least one of `{manifest, directory}` is
found. Manifest-based mode returns `""` for unknown runfiles;
directory-based mode falls back to `<directory>/<path>` and lets the
caller check the filesystem.

### `_repo_mapping`

Bzlmod builds emit a `_repo_mapping` file in the runfiles that rewrites
apparent repository names (what your code says) to canonical repository
names (what Bazel writes on disk). Both libraries read it at
construction and apply it during `Rlocation`.

The lookup algorithm on `some_apparent/path`:

1. If a mapping entry exists for `(some_apparent, source_repo)`,
   rewrite the first path component and look up
   `<canonical>/path` in the manifest.
2. Otherwise, if the largest entry `≤ (some_apparent, source_repo)` in
   the sorted map has `.first == some_apparent`, `.second` ends in
   `*`, and `source_repo` starts with the `.second` prefix, apply the
   wildcard rewrite.
3. Otherwise, look up the input path as-is.

The `source_repo` is either the handle's default (set at `Create` /
`rf_create_ex`) or the per-call override (`Rlocation(path, source_repo)`
/ `rf_rlocation_from(rf, path, source_repo, …)`).

`BAZEL_CURRENT_REPOSITORY` is defined by `rules_cc` for every target
that depends on the runfiles library; it evaluates to the canonical
repo name that contains the current target and is the correct value
for `source_repo` in C++.

### Path validation

`Rlocation` / `rf_rlocation` reject paths that would allow directory
traversal:

- Empty paths.
- Paths starting with `../` or `./`.
- Paths containing `/..`, `/./`, `//`.
- Paths ending in `/.`.

Absolute paths (Unix `/foo`, Windows `C:\foo`) are returned as-is,
without any manifest lookup.

### Manifest format

The manifest is a UTF-8 text file, one entry per line, in one of two
forms:

```text
raw_key raw_value                # first char is not space; no escaping
 escaped_key escaped_value       # first char IS space; both fields use escapes
```

Recognized escape sequences (in the second form only):

| Escape | Character   |
|--------|-------------|
| `\s`   | space       |
| `\n`   | newline     |
| `\b`   | backslash   |

Any other backslash sequence passes through literally. This matches
the format Bazel emits.

## Caching and thread safety

Both libraries maintain a process-wide cache of parsed data, keyed on
the resolved `(manifest, directory)` pair. The first `Create` /
`rf_create*` call for a given key does the file I/O and parsing;
subsequent calls with the same key are O(cache-lookup) and allocate
only a new handle wrapper.

- **C++**: `std::shared_ptr<const RunfilesData>` in a `std::mutex`-guarded
  `std::vector`. Released at process exit by normal C++ destructors.
- **C**: A refcounted `rf_runfiles_data` in a fixed-slot table
  (128 slots), guarded by a POSIX/Windows mutex. Released by an
  `atexit` handler.

All entry points are safe to call concurrently from multiple threads:

- `Create` / `rf_create*` / `WithSourceRepository` / `rf_with_source_repository`
  serialize on the library mutex only for cache lookup / insert and
  refcount updates.
- `Rlocation` / `rf_rlocation*` is lock-free. Once a handle exists, its
  `source_repository` is per-handle and immutable and the shared
  `RunfilesData` / `rf_runfiles_data` it points at is const after
  construction, so parallel lookups on the same or different handles
  never contend.
- `rf_free` / `delete` on a handle take the mutex only long enough to
  decrement the shared-data refcount.
- `rf_set_allocator` also takes the mutex, so it's safe to call
  concurrently with `rf_create*`. The only wrinkle is *ordering*: a
  concurrent create might snapshot either the old or the new allocator,
  depending on interleaving. This never produces a mismatch — the
  handle allocates and frees with the same allocator throughout its
  lifetime.

## Testing

The test suites in `//tests/runfiles/` cover manifest parsing (both
forms + escapes), envvar / argv0 / directory discovery,
`_repo_mapping` in all its variants (exact match, wildcard, per-call
source-repo override), and — for the C API — the custom allocator
hook, handle-remembers-allocator semantics, and shared-data reuse
across `rf_create` calls.

```bash
bazel test //tests/runfiles:runfiles_test    # C++ API
bazel test //tests/runfiles:runfiles_c_test  # C API
```
