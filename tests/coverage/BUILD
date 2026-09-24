load("@rules_shell//shell:sh_test.bzl", "sh_test")

sh_test(
    name = "collect_cc_coverage_test",
    size = "small",
    srcs = ["collect_cc_coverage_test.sh"],
    args = ["$(location //cc/coverage:collect_cc_coverage.sh)"],
    data = ["//cc/coverage:collect_cc_coverage.sh"],
    target_compatible_with = select({
        "@platforms//os:windows": ["@platforms//:incompatible"],
        "//conditions:default": [],
    }),
)
