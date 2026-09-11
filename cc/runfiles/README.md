# runfiles

For details see [//docs:runfiles.md](../../docs/runfiles.md).

## Testing

The test suites in `//tests/runfiles/` cover manifest parsing (both
forms + escapes), envvar / argv0 / directory discovery, and
`_repo_mapping` in all its variants (exact match, wildcard, per-call
source-repo override). The pure-C tests additionally exercise the
custom allocator hook and verify that `rf_rlocation` outputs route
through it.

```bash
bazel test //tests/runfiles:runfiles_test       # C++ API
bazel test //tests/runfiles:runfiles_c_test     # C API from C++
bazel test //tests/runfiles:runfiles_c_pure_test # C API from C
```
