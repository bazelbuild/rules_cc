load("//cc/toolchains:feature.bzl", "cc_feature")
load("//cc/toolchains/impl:args_for_compiler.bzl", "cc_args_for_compiler")

cc_feature(
    name = "feature",
    args = [":flags"],
    overrides = "//cc/toolchains/features/legacy:dependency_file",
    requires_any_of = [
        "//cc/toolchains/compiler:clang",
        "//cc/toolchains/compiler:gcc",
        "//cc/toolchains/compiler:mingw-gcc",
        "//cc/toolchains/compiler:emscripten",
    ],
    visibility = ["//visibility:public"],
)

cc_args_for_compiler(
    name = "flags",
    actions = ["//cc/toolchains/actions:compile_actions"],
    args = [
        "-MD",
        "-MF",
        "{dependency_file}",
    ],
    exclude_compilers = [
        "msvc-cl",
        "clang-cl",
    ],
    format = {"dependency_file": "//cc/toolchains/variables:dependency_file"},
    requires_not_none = "//cc/toolchains/variables:dependency_file",
)
