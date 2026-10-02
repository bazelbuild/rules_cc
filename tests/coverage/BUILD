load("@rules_shell//shell:sh_test.bzl", "sh_test")

sh_test(
    name = "collect_cc_coverage_test",
    size = "small",
    srcs = ["collect_cc_coverage_test.sh"],
    data = ["//cc/coverage:srcs"],
    target_compatible_with = ["@platforms//os:linux"],
)
