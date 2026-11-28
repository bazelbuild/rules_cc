# runfiles

See [//docs:runfiles.md](../../docs/runfiles.md).

## Testing

```bash
bazel test //tests/runfiles:runfiles_test        # C++ API
bazel test //tests/runfiles:runfiles_c_test      # C API, gtest
bazel test //tests/runfiles:runfiles_c_pure_test # C API, compiled as C
```
