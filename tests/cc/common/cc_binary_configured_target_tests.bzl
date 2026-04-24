"""Tests for cc_binary."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching", "subjects")
load("@rules_testing//lib:util.bzl", "TestingAspectInfo", "util")
load("//cc:action_names.bzl", "ACTION_NAMES")
load("//cc:cc_binary.bzl", _actual_cc_binary = "cc_binary")
load("//cc:cc_import.bzl", "cc_import")
load("//cc:cc_library.bzl", "cc_library")
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test")
load("//tests/cc/testutil:cc_binary_target_subject.bzl", "cc_binary_target_subject")
load("//tests/cc/testutil:link_action_subject.bzl", "link_action_subject")
load("//tests/cc/testutil/toolchains:features.bzl", "FEATURE_NAMES")

# Wrap cc_binary to mock out common dependencies.
def cc_binary(name, **kwargs):
    if "malloc" not in kwargs:
        # Avoid the real "malloc", which might use arbitrary toolchain actions and features.
        kwargs["malloc"] = "//tests/cc/testutil/toolchains:mock_malloc"
    _actual_cc_binary(
        name = name,
        **kwargs
    )

def _test_files_to_build(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/hello",
        srcs = ["hello.cc"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_files_to_build_impl,
        target = name + "/hello",
        **kwargs
    )

def _test_files_to_build_impl(env, target):
    cc_binary_subject = cc_binary_target_subject.from_target(env, target)
    cc_binary_subject.default_outputs().contains_exactly(["{package}/{name}{binary_extension}"])
    cc_binary_subject.executable().short_path_equals("{package}/{name}{binary_extension}")

def _test_headers_not_passed_to_linking_action(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/bye",
        srcs = ["bye.cc", "bye.h"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_headers_not_passed_to_linking_action_impl,
        target = name + "/bye",
        config_settings = {
            "//command_line_option:features": ["parse_headers"],
            "//command_line_option:process_headers_in_dependencies": True,
        },
        **kwargs
    )

def _test_headers_not_passed_to_linking_action_impl(env, target):
    link_action_subject.from_target(env, target).inputs().contains_none_of([
        matching.str_endswith(".h"),
        matching.str_endswith(".hpp"),
        matching.str_endswith(".hxx"),
    ])

def _test_no_duplicate_linkopts(name, **kwargs):
    # Regression test for b/943558: linkopts duplicated in linker invocation
    util.helper_target(
        cc_binary,
        name = name + "/hello",
        srcs = ["hello.cc"],
        linkopts = ["-fake_option"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_no_duplicate_linkopts_impl,
        target = name + "/hello",
        **kwargs
    )

def _test_no_duplicate_linkopts_impl(env, target):
    executable = target[DefaultInfo].files_to_run.executable
    link_action = env.expect.that_target(target).action_generating(executable.short_path)
    argv = link_action.actual.argv
    env.expect.that_collection(argv).contains("-fake_option")
    env.expect.that_collection(argv).transform(
        filter = matching.equals_wrapper("-fake_option"),
    ).contains_no_duplicates()

def _test_action_graph(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/hello",
        srcs = ["hello.cc"],
    )
    config_settings = {
        "//command_line_option:features": [
            "-no_dotd_file",
            "-parse_showincludes",
        ],
        "//command_line_option:force_pic": False,
    }

    cc_analysis_test(
        name = name,
        impl = _test_action_graph_impl,
        target = name + "/hello",
        config_settings = config_settings,
        **kwargs
    )

def _test_action_graph_impl(env, target):
    executable = target[DefaultInfo].files_to_run.executable
    link_action = env.expect.that_target(target).action_generating(executable.short_path)

    # link.inputs = { hello.o }
    hello_obj_files = [
        f
        for f in link_action.actual.inputs.to_list()
        if f.basename.startswith("hello.") and f.extension in ["o", "obj"]
    ]
    env.expect.that_collection(hello_obj_files).has_size(1)
    obj_file = hello_obj_files[0]

    # link.outputs = { hello }
    env.expect.that_collection(link_action.actual.outputs.to_list()).contains_exactly([executable])

    compile_action = env.expect.that_target(target).action_generating(obj_file.short_path)
    env.expect.that_str(compile_action.actual.mnemonic).equals("CppCompile")

    # compile.inputs = { hello_cc }
    compile_inputs = [f.short_path for f in compile_action.actual.inputs.to_list()]
    env.expect.that_collection(compile_inputs).contains_predicate(matching.str_endswith("hello.cc"))

    # compile.outputs = { hello.o, hello.d }
    compile_outputs = [f.short_path for f in compile_action.actual.outputs.to_list()]
    env.expect.that_collection(compile_outputs).contains(obj_file.short_path)
    env.expect.that_collection(compile_outputs).contains_predicate(matching.str_endswith("hello.o"))

    # TODO: Test stripped action

def _make_dll(name):
    # make a fake dll so the dll shows up in the output directory (where the
    # binary will be) instead of as a source file (the way cc_import on its own would)
    # Example taken from
    # https://github.com/bazelbuild/bazel/blob/f720ed385e245e292b0afe19ebd84e4283c30565/examples/windows/dll/windows_dll_library.bzl
    dll = name + ".dll"
    mask = name + "_mask"

    util.helper_target(
        cc_binary,
        name = dll,
        srcs = ["hello.cc"],
        linkshared = 1,
    )

    # Mask the cc_binary behind a cc_import so we can depend on it as a library
    util.helper_target(
        cc_import,
        name = mask,
        shared_library = dll,
    )

    # cc_imports are always source files, so make it a generated file again
    util.helper_target(
        cc_library,
        name = name,
        deps = [mask],
    )

def _test_runtime_dynamic_libraries_copy_behavior(name, **kwargs):
    sub_dir_lib = name + "/dst/sub/sub_dir_lib"
    same_dir_lib = name + "/dst/same_dir_lib"
    binary_target = name + "/dst/hello"

    # project a dll into the same directory as the binary, and a second one in
    # a subdirectory
    _make_dll(same_dir_lib)
    _make_dll(sub_dir_lib)

    util.helper_target(
        cc_binary,
        name = binary_target,
        srcs = ["hello.cc"],
        deps = [
            same_dir_lib,
            sub_dir_lib,
        ],
        linkstatic = False,
    )

    analysis_test(
        name = name,
        impl = _test_runtime_dynamic_libraries_copy_behavior_impl,
        target = binary_target,
        # TODO: This would be better-done with the mock toolchain, once that is
        # wired up
        attrs = {
            "copy_feature_supported": attr.bool(),
        },
        attr_values = {
            "copy_feature_supported": select({
                # copy_dynamic_libraries_to_binary is only defined in the
                # windows toolchain currently
                "@platforms//os:windows": True,
                "//conditions:default": False,
            }),
            "size": "small",
        },
        **kwargs
    )

def _test_runtime_dynamic_libraries_copy_behavior_impl(env, target):
    if not env.ctx.attr.copy_feature_supported:
        return

    test_name = env.ctx.label.name

    expected_copied_library = "tests/cc/common/{name}/dst/sub_dir_lib.dll".format(
        name = test_name,
    )
    expected_same_dir_library = "tests/cc/common/{name}/dst/same_dir_lib.dll".format(
        name = test_name,
    )

    # Both libraries should be listed as runtime dependencies, but...
    expected_libraries = [expected_copied_library, expected_same_dir_library]

    env.expect \
        .that_target(target) \
        .output_group("runtime_dynamic_libraries") \
        .contains_exactly(expected_libraries)

    actions = {}
    for action in target[TestingAspectInfo].actions:
        if action.mnemonic != "Symlink":
            continue

        for output in action.outputs.to_list():
            if output.short_path in expected_libraries:
                actions[output.short_path] = action

    # ... only one of the libraries should have a Symlink action (Copying
    # Execution Dynamic Library) since the other one should already be in the
    # same dir
    expected_copies = [expected_copied_library]
    env.expect.that_dict(actions).keys().contains_exactly(expected_copies)

def _test_pic(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/hello",
        srcs = ["hello.cc"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_pic_impl,
        target = name + "/hello",
        test_features = [FEATURE_NAMES.supports_pic],
        config_settings = {
            "//command_line_option:force_pic": True,
        },
        **kwargs
    )

def _test_pic_impl(env, target):
    executable = target[DefaultInfo].files_to_run.executable
    link_action = env.expect.that_target(target).action_generating(executable.short_path)
    hello_obj_files = [
        f
        for f in link_action.actual.inputs.to_list()
        if f.basename.startswith("hello.") and f.extension in ["o", "obj"]
    ]

    env.expect.that_collection(hello_obj_files).has_size(1)
    env.expect.that_file(hello_obj_files[0]).basename().equals("hello.pic.o")

def _test_missing_action_config_for_strip_is_a_rule_error(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/hello",
        srcs = ["hello.cc"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_missing_action_config_for_strip_is_a_rule_error_impl,
        target = name + "/hello",
        test_features = [FEATURE_NAMES.no_legacy_features, FEATURE_NAMES.pic],
        with_action_configs = [
            ACTION_NAMES.cpp_compile,
            ACTION_NAMES.cpp_link_static_library,
            ACTION_NAMES.cpp_link_executable,
        ],
        expect_failure = True,
        **kwargs
    )

def _test_missing_action_config_for_strip_is_a_rule_error_impl(env, target):
    env.expect.that_target(target).failures().contains_predicate(
        matching.contains("Expected action_config for 'strip' to be configured."),
    )

def _test_sanitize_pwd_feature_enabled(name, **kwargs):
    """sanitize_pwd is on by default, PWD should be set via the feature's env_set."""
    util.helper_target(
        cc_binary,
        name = name + "/hello",
        srcs = ["hello.cc"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_sanitize_pwd_feature_enabled_impl,
        target = name + "/hello",
        config_settings = {
            "//command_line_option:platforms": str(Label("//tests/cc/testutil/toolchains:linux_x86_64")),
        },
        **kwargs
    )

def _test_sanitize_pwd_feature_enabled_impl(env, target):
    link_action = link_action_subject.from_target(env, target)
    link_action.env().get("PWD", factory = subjects.str).equals("/proc/self/cwd")

def _test_sanitize_pwd_feature_disabled(name, **kwargs):
    """When sanitize_pwd is explicitly disabled, the legacy requires_darwin fallback still applies."""
    util.helper_target(
        cc_binary,
        name = name + "/hello",
        srcs = ["hello.cc"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_sanitize_pwd_feature_disabled_impl,
        target = name + "/hello",
        config_settings = {
            "//command_line_option:features": ["-sanitize_pwd"],
        },
        **kwargs
    )

def _test_sanitize_pwd_feature_disabled_impl(env, target):
    link_action = link_action_subject.from_target(env, target)
    link_action.env().get("PWD", factory = subjects.str).equals("/proc/self/cwd")

def _test_sanitize_pwd_macos_no_pwd(name, **kwargs):
    """On macOS, sanitize_pwd is enabled but should not set PWD."""
    util.helper_target(
        cc_binary,
        name = name + "/hello",
        srcs = ["hello.cc"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_sanitize_pwd_macos_no_pwd_impl,
        target = name + "/hello",
        config_settings = {
            "//command_line_option:platforms": str(Label("//tests/cc/testutil/toolchains:macos_arm64")),
        },
        **kwargs
    )

def _test_sanitize_pwd_macos_no_pwd_impl(env, target):
    link_action = link_action_subject.from_target(env, target)
    link_action.env().keys().not_contains("PWD")

def _system_include_paths_from_argv(argv):
    system_include_paths = []
    for i in range(len(argv) - 1):
        if argv[i] == "-isystem":
            system_include_paths.append(argv[i + 1])
    return system_include_paths

def _test_system_include_paths_reclassifies_local_includes_without_propagation(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/dep",
        srcs = ["dep.cc", "dep_local.h"],
        hdrs = ["dep_public.h"],
        local_includes = ["dep_private"],
    )
    util.helper_target(
        cc_binary,
        name = name + "/hello",
        srcs = ["hello.cc", "hello_local.h"],
        deps = [name + "/dep"],
        local_includes = ["hello_private"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_system_include_paths_reclassifies_local_includes_without_propagation_impl,
        target = name + "/hello",
        config_settings = {
            "//command_line_option:features": ["system_include_paths"],
        },
        **kwargs
    )

def _test_system_include_paths_reclassifies_local_includes_without_propagation_impl(env, target):
    executable = target[DefaultInfo].files_to_run.executable
    link_action = env.expect.that_target(target).action_generating(executable.short_path)
    hello_obj_files = [
        f
        for f in link_action.actual.inputs.to_list()
        if f.basename.startswith("hello.") and f.extension in ["o", "obj"]
    ]

    env.expect.that_collection(hello_obj_files).has_size(1)
    compile_action = env.expect.that_target(target).action_generating(hello_obj_files[0].short_path)
    system_include_paths = _system_include_paths_from_argv(compile_action.actual.argv)

    env.expect.that_collection(system_include_paths).contains_predicate(
        matching.str_endswith("/hello_private"),
    )
    env.expect.that_collection(system_include_paths).transform(
        filter = matching.str_endswith("/dep_private"),
    ).contains_exactly([])

def _test_system_include_paths_reclassifies_local_includes_after_includes(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/dep",
        srcs = ["dep.cc", "dep_local.h"],
        hdrs = ["dep_public.h"],
        includes = ["dep_includes"],
        local_includes = ["dep_private"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_system_include_paths_reclassifies_local_includes_after_includes_impl,
        target = name + "/dep",
        config_settings = {
            "//command_line_option:features": ["system_include_paths"],
        },
        **kwargs
    )

def _test_system_include_paths_reclassifies_local_includes_after_includes_impl(env, target):
    dep_compile_actions = []
    for action in target[TestingAspectInfo].actions:
        if action.mnemonic != "CppCompile":
            continue
        for output in action.outputs.to_list():
            if output.basename.startswith("dep.") and output.extension in ["o", "obj"]:
                dep_compile_actions.append(action)
                break

    env.expect.that_collection(dep_compile_actions).has_size(1)
    dep_system_include_paths = _system_include_paths_from_argv(dep_compile_actions[0].argv)

    dep_system_include_kinds = []
    for path in dep_system_include_paths:
        if path.endswith("/dep_includes"):
            dep_system_include_kinds.append("dep_includes")
        elif path.endswith("/dep_private"):
            dep_system_include_kinds.append("dep_private")

    env.expect.that_collection(dep_system_include_kinds).contains_at_least([
        "dep_includes",
        "dep_private",
    ]).in_order()

def cc_binary_configured_target_tests(name):
    tests = [
        _test_files_to_build,
        _test_headers_not_passed_to_linking_action,
        _test_no_duplicate_linkopts,
        _test_action_graph,
        _test_runtime_dynamic_libraries_copy_behavior,
        _test_pic,
        _test_missing_action_config_for_strip_is_a_rule_error,
    ]

    # sanitize_pwd is implemented in Starlark in rules_cc, requires Bazel 9+.
    if bazel_features.cc.cc_common_is_in_rules_cc:
        tests.extend([
            _test_sanitize_pwd_feature_enabled,
            _test_sanitize_pwd_feature_disabled,
            _test_sanitize_pwd_macos_no_pwd,
            _test_system_include_paths_reclassifies_local_includes_after_includes,
            _test_system_include_paths_reclassifies_local_includes_without_propagation,
        ])

    test_suite(
        name = name,
        tests = tests,
    )
