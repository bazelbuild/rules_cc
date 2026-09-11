# Runfiles

`rules_cc` provides two source-level libraries for looking up runfiles from
Bazel-built C and C++ programs. Both implement the same algorithm
(manifest parsing, `_repo_mapping` support, argv0/envvar path discovery,
prefix-match fallback, wildcard rewriting).

| Library | Bazel target                        | Include                              |
|---------|-------------------------------------|--------------------------------------|
| C++     | `@rules_cc//cc/runfiles:runfiles`   | `rules_cc/cc/runfiles/runfiles.h`    |
| Pure C  | `@rules_cc//cc/runfiles:runfiles_c` | `rules_cc/cc/runfiles/runfiles_c.h`  |

The C library exposes a pluggable allocator: every `rf_create*` entry
point takes a `const rf_allocator*` as its first argument. Pass `NULL`
for libc `malloc`/`realloc`/`free`, or a caller-owned vtable to route
the library's internal allocations (parsed manifest, `_repo_mapping`
table, parser scratch, repo-mapping join scratch) through your own
backend. Variable-length outputs (resolved paths) go into a
caller-provided buffer with an snprintf-style "here's the required
size" report — callers decide when to grow. The C++ facade wraps this
with `std::string` and `std::allocator`, so C++ consumers never touch
the allocator vtable and never manage output-buffer growth themselves.

## Choosing between them

Use the C++ library from any C++ source. It's the default and lets you
work with `std::string` / `std::unique_ptr` directly.

Use the pure-C library when you need to look up runfiles from C code,
when you cannot link libstdc++, or when you want a custom allocator.
Typical cases: embedded programs, foreign-function bindings (Rust, Go,
Fortran, …), and toolchains that ship their own C runtime.

Mixing both in the same process is safe. Each `Runfiles` C++ instance
owns exactly one underlying `rf_runfiles` handle, and each `rf_create*`
call parses fresh — there is no shared cache across handles in either
direction.

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
`//cc/runfiles:runfiles`; it names the canonical repo that contains the
calling target and is required for `_repo_mapping` rewrites (see below)
to resolve correctly.

### In a `cc_test`

Use `Runfiles::CreateForTest` instead of `Runfiles::Create` — it reads
`RUNFILES_MANIFEST_FILE` and `TEST_SRCDIR` (set by `bazel test`) instead
of doing argv0-based discovery.

```cpp
std::unique_ptr<Runfiles> r(
    Runfiles::CreateForTest(BAZEL_CURRENT_REPOSITORY, &error));
```

### API

Full API in [`cc/runfiles/runfiles.h`](../cc/runfiles/runfiles.h). The
public surface is:

- `Runfiles::Create(argv0, [manifest, dir,] [source_repo,] error)` and
  `Runfiles::CreateForTest([source_repo,] error)` — construction.
- `std::string Rlocation(path)` /
  `std::string Rlocation(path, source_repo)` — path lookup.
- `std::unique_ptr<Runfiles> WithSourceRepository(source_repo)` —
  derive a sibling instance that shares the underlying handle but
  uses a different default source repository. The handle is refcounted
  via `std::shared_ptr` under the hood, so the derived instance stays
  live even after the parent is dropped.
- `const std::vector<std::pair<std::string, std::string>>& EnvVars() const` —
  environment variables to publish to subprocesses.

Each `Create` call parses the manifest and `_repo_mapping` from disk
and returns a fully-owning `Runfiles*`; there is no process-wide cache.
Callers that want to reuse a parse across scopes / threads should hold
the returned `Runfiles*` themselves.

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
  // First arg is the allocator; NULL uses libc malloc/realloc/free.
  // Env variables are NOT read: pass explicit manifest / dir paths
  // (or "" to defer to argv0-based discovery).
  rf_runfiles* rf = rf_create(/*alloc=*/NULL, argv[0],
                              /*manifest=*/"", /*dir=*/"",
                              /*source_repo=*/"", err, sizeof(err));
  if (!rf) {
    fputs(err, stderr);
    return 1;
  }

  char buf[4096];
  size_t needed = 0;
  rf_rlocation_status s = rf_rlocation(
      rf, "my_workspace/path/to/data.txt",
      /*source_repository=*/NULL,  // NULL -> handle's default source repo
      buf, sizeof(buf), &needed);
  switch (s) {
    case RF_RLOCATION_OK:
      /* buf is NUL-terminated; `needed` == strlen(buf). */
      break;
    case RF_RLOCATION_BUF_TOO_SMALL:
      /* buf is untouched; `needed` = required size. Caller decides:
         grow to needed+1 and retry, bail with an error, or truncate. */
      break;
    case RF_RLOCATION_NOT_FOUND:
      /* Well-formed path but the runfile is unknown to this handle. */
      break;
    case RF_RLOCATION_INVALID_PATH:
      /* Path fails validation (empty, ..-traversal, //, etc.). */
      break;
    case RF_RLOCATION_ALLOC_FAILED:
      /* Handle's allocator failed during the internal _repo_mapping
         join scratch (rare — bounded by input length). */
      break;
  }

  rf_free(rf);
  return 0;
}
```

`rf_rlocation` writes into a caller-owned buffer. On success, `*needed`
is `strlen(buf)`. On `RF_RLOCATION_BUF_TOO_SMALL`, `buf` is left
untouched (no partial write) and `*needed` reports the exact byte
length the result would occupy — retry once with a buffer of at least
`*needed + 1` bytes. `buf = NULL, buf_cap = 0` reduces the call to a
pure size query (returns `RF_RLOCATION_BUF_TOO_SMALL` with the
required size), useful when the caller wants to allocate exactly-sized
storage in one shot.

Callers who want zero-alloc lookups plug an arena into `rf_allocator`
for the library's internal scratch (the repo-mapping join buffer);
their own output buffer is already zero-alloc since they own it.

A future release may add an ergonomic alloc-out companion (e.g.
`rf_rlocation_alloc(rf, path, sr, char** out)`) that hides the
grow-and-retry dance behind the vtable — the caller-buffer form here
is the low-level primitive both shapes would share.

### In a `cc_test`

Use `rf_create_for_test`, which reads `RUNFILES_MANIFEST_FILE` and
`TEST_SRCDIR` from the environment. This is the only entry point in the
C library that reads process env vars — production code should call
`getenv` (or the platform equivalent) itself and pass the results to
`rf_create`.

```c
char err[256];
rf_runfiles* rf = rf_create_for_test(/*alloc=*/NULL, /*source_repo=*/"",
                                     err, sizeof(err));
```

### Custom allocator

Every internal heap allocation — the handle itself, the parsed
manifest, the `_repo_mapping` table, transient parser scratch, the
path-discovery working buffers, and the repo-mapping join scratch used
by `rf_rlocation` — routes through the `rf_allocator` you pass to
`rf_create*`. Skip the parameter (pass `NULL`) and it defaults to libc.
`rf_rlocation`'s output buffer is caller-owned and NEVER routed through
the vtable; the vtable only sees the library's *internal* allocations.

```c
static void* my_malloc(void* ud, size_t n)           { /* … */ }
static void* my_realloc(void* ud, void* p, size_t n) { /* … */ }
static void  my_free(void* ud, void* p)              { /* … */ }

rf_allocator my_alloc = {my_malloc, my_realloc, my_free,
                         /*userdata=*/NULL};
rf_runfiles* rf = rf_create(&my_alloc, argv[0], "", "", "", err, sizeof(err));
```

- The vtable is **copied into the handle** at construction, so a
  short-lived (e.g. stack-local) `rf_allocator` is safe — you don't
  need to keep the original struct alive.
- The `userdata` pointer, however, IS held by reference: whatever it
  points at must outlive the last live `rf_runfiles*` built under this
  allocator.
- File I/O (`fopen`, `fclose`, `fgets`) is inherent to libc and cannot
  be redirected through the allocator hook.
- No global setter — no `rf_set_allocator`; the allocator lives per
  handle. Different handles in the same process can use different
  allocators without collision.

### Subprocess environment

The C library publishes three env-var pairs — `RUNFILES_MANIFEST_FILE`,
`RUNFILES_DIR`, and `JAVA_RUNFILES` (compatibility alias for
`RUNFILES_DIR`) — that a launched child needs to find the same runfiles
tree. Iterate with:

```c
int n = rf_env_vars_count();  // currently always 3
for (int i = 0; i < n; ++i) {
  const char* k = rf_env_var_key(i);        // static string — do NOT free
  const char* v = rf_env_var_value(rf, i);  // handle-owned — do NOT free
  setenv(k, v, /*overwrite=*/1);
}
```

The keys are static strings from a fixed table; the values alias the
handle's internal `manifest_file` / `directory` storage and are valid
until `rf_free`. Neither is caller-owned, so neither needs freeing.

### API

Full API in [`cc/runfiles/runfiles_c.h`](../cc/runfiles/runfiles_c.h).
The public surface is:

- `rf_create(alloc, argv0, manifest, dir, source_repo, err, err_len)` —
  main construction entry point. Env vars are NOT read; caller supplies
  everything.
- `rf_create_for_test(alloc, source_repo, err, err_len)` — test
  convenience that reads `RUNFILES_MANIFEST_FILE` and `TEST_SRCDIR`
  from the environment.
- `rf_rlocation(rf, path, source_repository, buf, buf_cap, needed)` —
  caller-buffer path lookup. `source_repository = NULL` uses the
  handle's default; any non-`NULL` string (including `""` for the main
  workspace) is an explicit override. Returns an `rf_rlocation_status`;
  on `RF_RLOCATION_OK`, `buf` holds a NUL-terminated string of length
  `*needed`; on `RF_RLOCATION_BUF_TOO_SMALL`, `buf` is untouched and
  `*needed` reports the exact size a retry needs.
- `rf_env_vars_count()` / `rf_env_var_key(i)` / `rf_env_var_value(rf, i)` —
  subprocess environment publication. Keys are static strings; values
  alias handle-owned storage. Neither is caller-owned.
- `rf_free(rf)` — destructor. No-op on `NULL`. Uses the allocator that
  was passed to `rf_create*`.
- `rf_is_absolute(path)` — utility; matches the algorithm the library
  uses internally.

## Discovery, path lookup, and repo mapping

Both libraries implement identical algorithms. This section describes
what they do.

### Path discovery order

Both libraries try, in order:

1. Explicit `manifest` / `directory` arguments (if you called
   `Runfiles::Create(argv0, mf, dir, …)` or `rf_create(alloc, argv0, mf,
   dir, …)`).
2. Environment variables — `RUNFILES_MANIFEST_FILE`, `RUNFILES_DIR` (for
   `Runfiles::Create` from C++, or when a C caller passes env-read
   values into `rf_create`) or `TEST_SRCDIR` (for
   `Runfiles::CreateForTest` / `rf_create_for_test`). On Windows these
   are read via `GetEnvironmentVariableW` so env vars set with
   `SetEnvironmentVariableW` (which don't touch the CRT `_environ`
   block) and non-ASCII values are both visible.
3. Argv0-based fallback: `<argv0>.runfiles/MANIFEST` +
   `<argv0>.runfiles/`, then `<argv0>.runfiles_manifest`.
4. If a manifest was found but no directory, derive the directory by
   stripping the `_manifest` or `/MANIFEST` suffix.

The library succeeds if at least one of `{manifest, directory}` is
found. Manifest-based mode returns `""` (or `RF_RLOCATION_NOT_FOUND`)
for unknown runfiles; directory-based mode falls back to
`<directory>/<path>` and lets the caller check the filesystem.

Resolved paths on the C side go into a caller-provided buffer with an
snprintf-style "here's the required size" report — the caller decides
when to grow. The C++ facade wraps this with a `std::string` that
grows once from a 4 KB stack-backed starting size to the exact
reported length, so Windows extended-length (`\\?\`) paths up to
~32 767 chars round-trip cleanly with no fixed cap.

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
`rf_create`) or the per-call override (`Rlocation(path, source_repo)` /
`rf_rlocation(rf, path, source_repo, …)`).

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
- Backslash-separator variants of any of the above (rejected on all
  platforms; Bazel manifests use forward slashes, so a `\` in a caller-
  supplied key is suspicious and closes a Windows traversal hole).

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

| Escape | Character |
|--------|-----------|
| `\s`   | space     |
| `\n`   | newline   |
| `\b`   | backslash |

Any other backslash sequence passes through literally. This matches
the format Bazel emits.

## Lifetime and thread safety

There is no process-wide cache in either library. Each `Create` /
`rf_create*` call reads the manifest and `_repo_mapping` from disk and
returns an instance that fully owns its parsed data. Callers who want
to reuse a parse should hold the returned handle themselves (e.g. via
`std::shared_ptr<Runfiles>` on the C++ side, `WithSourceRepository` for
derived instances that share the parse, or by holding the
`rf_runfiles*` in a struct on the C side).

Different handles are fully independent and safe to use concurrently
from different threads. A single handle is safe for parallel `Rlocation`
/ `rf_rlocation` reads — the parsed state is immutable after
construction — but mixing reads with destruction is the caller's
responsibility (same contract as `std::vector`).
