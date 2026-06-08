# rules_cc integration tests

These tests can run with Bazel normally (i.e. via
`bazel test //tests/integration:[test_target]`), but require a copy of Bazel
in order to run.

Currently this Bazel is retrieved from your PATH variable (like `which bazel`).
In order for these test to function it is necessary that the found copy of
Bazel is actually the standalone Bazel binary and not a shell wrapper or
similar because it is simply copied into the test workspace and invoked.

If `bazel-real` is found that will be used instead (it assumed that `bazel`
is the standard shell wrapper in this case).

Use of bzlmod is required in order to execute these tests.
