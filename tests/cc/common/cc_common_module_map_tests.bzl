"""Tests for passing a custom module map to cc_common.compile."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@rules_testing//lib:analysis_test.bzl", "test_suite")
load("@rules_testing//lib:util.bzl", "util")
load("//cc:find_cc_toolchain.bzl", "find_cc_toolchain", "use_cc_toolchain")
load("//cc/common:cc_common.bzl", "cc_common")
load("//cc/common:cc_info.bzl", "CcInfo")
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test")

def _custom_module_map_library_impl(ctx):
    cc_toolchain = find_cc_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    module_map = ctx.actions.declare_file(ctx.label.name + ".custom.cppmap")
    ctx.actions.write(
        module_map,
        'module "{}" {{\n'.format(ctx.label) + "".join([
            '  textual header "{}"\n'.format(hdr.path)
            for hdr in ctx.files.hdrs
        ]) + "}\n",
    )
    compilation_context, _ = cc_common.compile(
        name = ctx.label.name,
        actions = ctx.actions,
        cc_toolchain = cc_toolchain,
        feature_configuration = feature_configuration,
        public_hdrs = ctx.files.hdrs,
        module_map = cc_common.create_module_map(file = module_map),
        do_not_generate_module_map = True,
    )
    return [CcInfo(compilation_context = compilation_context)]

_custom_module_map_library = rule(
    implementation = _custom_module_map_library_impl,
    attrs = {
        "hdrs": attr.label_list(allow_files = True),
    },
    fragments = ["cpp"],
    toolchains = use_cc_toolchain(),
)

def _test_custom_module_map_is_compiled(name):
    util.helper_target(
        _custom_module_map_library,
        name = name + "/lib",
        hdrs = ["header.h"],
        features = ["header_modules"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_custom_module_map_is_compiled_impl,
        target = name + "/lib",
        test_features = ["header_modules_feature_configuration"],
    )

def _test_custom_module_map_is_compiled_impl(env, target):
    env.expect.that_collection(
        [action.mnemonic for action in target.actions],
    ).not_contains("CppModuleMap")
    env.expect.that_target(target).action_generating(
        "{package}/_objs/{test_name}/lib/lib.pcm",
    ).inputs().contains("{package}/{test_name}/lib.custom.cppmap")

def cc_common_module_map_tests(name):
    test_suite(
        name = name,
        tests = [
            _test_custom_module_map_is_compiled,
        ] if bazel_features.cc.cc_common_is_in_rules_cc else [],
    )
