load("//cc/toolchains:args.bzl", "cc_args")
load("//cc/toolchains:feature.bzl", "cc_feature")
load("//cc/toolchains:feature_set.bzl", "cc_feature_set")

package(default_visibility = ["//visibility:public"])

# Clang toolchains opt in by adding this set to known_features.
# Enable tracing with features = ["trace"] and request --output_groups=trace_files.
cc_feature_set(
    name = "feature",
    all_of = [
        ":trace",
        ":clang_trace",
    ],
)

cc_feature(
    name = "trace",
    feature_name = "trace",
    implies = [":clang_trace"],
)

cc_feature(
    name = "clang_trace",
    args = [":trace_args"],
    feature_name = "clang_trace",
)

cc_args(
    name = "trace_args",
    actions = [
        "//cc/toolchains/actions:c_compile",
        "//cc/toolchains/actions:cpp_compile",
        "//cc/toolchains/actions:cpp_module_compile",
        "//cc/toolchains/actions:cpp20_module_compile",
        "//cc/toolchains/actions:objc_compile",
        "//cc/toolchains/actions:objcpp_compile",
    ],
    args = ["-ftime-trace"],
    visibility = ["//visibility:private"],
)
