load("@rules_cc//cc/toolchains:args.bzl", "cc_args")
load("@rules_cc//cc/toolchains:toolchain.bzl", "cc_toolchain")

# For now, each toolchain is only declared to be compatible
# when exec_platform == target_platform.
PLATFORMS = {
    "linux-x86_64": [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
    ],
}

cc_args(
    name = "warnings",
    actions = [
        "@rules_cc//cc/toolchains/actions:c_compile",
        "@rules_cc//cc/toolchains/actions:cpp_compile_actions",
    ],
    args = [
        "-Wall",
        "-Wextra",
        "-Wpedantic",
    ],
)

cc_args(
    name = "no_canonical_prefixes",
    actions = [
        "@rules_cc//cc/toolchains/actions:c_compile",
        "@rules_cc//cc/toolchains/actions:cpp_compile_actions",
    ],
    args = ["-no-canonical-prefixes"],
)

[
    cc_toolchain(
        name = "host-{}-config".format(platform_name),
        args = select({
            "@platforms//os:linux": [
                "@linux_sysroot//:sysroot",
            ],
            "//conditions:default": [],
        }) + [
            ":no_canonical_prefixes",
            ":warnings",
        ],
        tool_map = "@clang-{}//:all_tools".format(platform_name),
        known_features = ["@rules_cc//cc/toolchains/args:experimental_replace_legacy_action_config_features"],
        enabled_features = ["@rules_cc//cc/toolchains/args:experimental_replace_legacy_action_config_features"],
        target_compatible_with = constraints,
    )
    for platform_name, constraints in PLATFORMS.items()
]

[
    toolchain(
        name = "host-{}".format(platform_name),
        exec_compatible_with = constraints,
        target_compatible_with = constraints,
        toolchain = ":host-{}-config".format(platform_name),
        toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
    )
    for platform_name, constraints in PLATFORMS.items()
]
