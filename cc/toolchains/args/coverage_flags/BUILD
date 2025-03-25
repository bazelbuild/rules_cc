load("//cc/toolchains:args.bzl", "cc_args")
load("//cc/toolchains:feature.bzl", "cc_feature")
load("//cc/toolchains:feature_set.bzl", "cc_feature_set")

cc_feature_set(
    name = "feature",
    all_of = [
        ":llvm_feature",
        ":gcc_feature",
    ],
    visibility = ["//visibility:public"],
)

cc_feature(
    name = "llvm_feature",
    args = [
        ":llvm_compile_flags",
        ":llvm_link_flags",
    ],
    feature_name = "_llvm_feature",
    requires_any_of = ["//cc/toolchains/features:llvm_coverage_map_format"],
)

cc_args(
    name = "llvm_compile_flags",
    actions = ["//cc/toolchains/actions:compile_actions"],
    args = [
        "-fprofile-instr-generate",
        "-fcoverage-mapping",
    ],
)

cc_args(
    name = "llvm_link_flags",
    actions = ["//cc/toolchains/actions:link_actions"],
    args = [
        "-fprofile-instr-generate",
    ],
)

cc_feature(
    name = "gcc_feature",
    args = [
        ":gcc_compile_flags",
        ":gcc_link_flags",
    ],
    feature_name = "_gcc_feature",
    requires_any_of = ["//cc/toolchains/features:gcc_coverage_map_format"],
)

cc_args(
    name = "gcc_compile_flags",
    actions = ["//cc/toolchains/actions:compile_actions"],
    args = [
        "-fprofile-arcs",
        "-ftest-coverage",
    ],
)

cc_args(
    name = "gcc_link_flags",
    actions = ["//cc/toolchains/actions:link_actions"],
    args = [
        "--coverage",
    ],
)
