"""White-box unit test of cc_binary rule."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching", "subjects")
load("@rules_testing//lib:util.bzl", "TestingAspectInfo", "util")
load("//cc:action_names.bzl", "ACTION_NAMES")
load("//cc:cc_binary.bzl", _actual_cc_binary = "cc_binary")
load("//cc:cc_import.bzl", "cc_import")
load("//cc:cc_library.bzl", "cc_library")
load("//cc:cc_test.bzl", _actual_cc_test = "cc_test")
load("//cc/common:cc_common.bzl", "cc_common")
load("//cc/common:cc_info.bzl", "CcInfo")
load("//tests/cc/testutil:cc_analysis_test.bzl", "MOCK_TOOLCHAINS", "cc_analysis_test")
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

# Wrap cc_test to mock out common dependencies.
def cc_test(name, **kwargs):
    if "malloc" not in kwargs:
        # Avoid the real "malloc", which might use arbitrary toolchain actions and features.
        kwargs["malloc"] = "//tests/cc/testutil/toolchains:mock_malloc"
    _actual_cc_test(
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
    link_action = link_action_subject.from_target(env, target)
    link_action.argv().contains("-fake_option")
    link_action.argv().transform(
        filter = matching.equals_wrapper("-fake_option"),
    ).contains_no_duplicates()

def _test_action_graph(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/hello",
        srcs = ["hello.cc"],
    )
    config_settings = {
        "//command_line_option:force_pic": False,
    }

    cc_analysis_test(
        name = name,
        impl = _test_action_graph_impl,
        target = name + "/hello",
        config_settings = config_settings,
        test_features = [
            "no_dotd_file",
        ],
        **kwargs
    )

def _test_action_graph_impl(env, target):
    executable = target[DefaultInfo].files_to_run.executable
    link_action = link_action_subject.from_target(env, target)

    # link.inputs = { hello.o }
    hello_obj_files = [
        f
        for f in link_action.actual.inputs.to_list()
        if f.basename.startswith("hello.") and f.extension in ["o", "obj"]
    ]
    env.expect.that_collection(hello_obj_files).has_size(1)
    obj_file = hello_obj_files[0]

    # link.outputs = { hello }
    link_action.outputs().contains_exactly([executable.short_path])

    compile_action = env.expect.that_target(target).action_generating(obj_file.short_path)
    compile_action.mnemonic().equals("CppCompile")

    # compile.inputs = { hello_cc }
    compile_action.inputs().contains("{package}/hello.cc")

    # compile.outputs = { hello.o } (mock toolchain doesn't generate .d)
    compile_outputs = compile_action.actual.outputs.to_list()
    env.expect.that_collection(compile_outputs).has_size(1)
    env.expect.that_collection(compile_outputs).contains(obj_file)

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
    link_action = link_action_subject.from_target(env, target)
    hello_obj_files = [
        f
        for f in link_action.actual.inputs.to_list()
        if f.basename.startswith("hello.pic.") and f.extension in ["o", "obj"]
    ]

    env.expect.that_collection(hello_obj_files).has_size(1)

def _generated_def_file_test(name, impl, with_action_configs = None, **kwargs):
    if with_action_configs == None:
        with_action_configs = []

    util.helper_target(
        cc_binary,
        name = name + "/hello",
        srcs = ["hello.cc"],
        linkshared = True,
    )
    cc_analysis_test(
        name = name,
        impl = impl,
        target = name + "/hello",
        test_features = [
            FEATURE_NAMES.copy_dynamic_libraries_to_binary,
            FEATURE_NAMES.targets_windows,
            FEATURE_NAMES.windows_export_all_symbols,
        ],
        with_action_configs = with_action_configs,
        **kwargs
    )

def _generated_def_file_action(env, target):
    action = cc_binary_target_subject.from_target(env, target).action_generating(
        "{package}/{name}.gen.def",
    )
    action.mnemonic().equals("DefParser")
    return action

# buildifier: disable=unused-variable
def _test_generated_def_file_uses_default_tool(name, **kwargs):
    _generated_def_file_test(
        name,
        _test_generated_def_file_uses_default_tool_impl,
        **kwargs
    )

def _test_generated_def_file_uses_default_tool_impl(env, target):
    _generated_def_file_action(env, target).argv().contains_predicate(
        matching.contains("tools/def_parser"),
    )

# buildifier: disable=unused-variable
def _test_generated_def_file_uses_toolchain_action(name, **kwargs):
    _generated_def_file_test(
        name,
        _test_generated_def_file_uses_toolchain_action_impl,
        with_action_configs = [ACTION_NAMES.generate_def_file],
        **kwargs
    )

def _test_generated_def_file_uses_toolchain_action_impl(env, target):
    _generated_def_file_action(env, target).argv().contains_predicate(
        matching.contains("def_parser_tool"),
    )

def _test_duplicate_linkopts(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/lib",
        srcs = ["lib.cc"],
        linkopts = [
            "-z bar",
            "-z baz",
        ],
    )

    util.helper_target(
        cc_binary,
        name = name + "/app",
        srcs = ["app.cc"],
        linkopts = [
            "-z foo",
            "-z bar",
        ],
        deps = [name + "/lib"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_duplicate_linkopts_impl,
        target = name + "/app",
        **kwargs
    )

def _test_duplicate_linkopts_impl(env, target):
    executable = target[DefaultInfo].files_to_run.executable
    link_action = env.expect.that_target(target).action_generating(executable.short_path)
    argv = link_action.actual.argv
    env.expect.that_collection(argv).contains_at_least([
        "-z",
        "foo",
        "-z",
        "bar",
        "-z",
        "bar",
        "-z",
        "baz",
    ]).in_order()

def _test_unsupported_src_file(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/bad",
        srcs = ["bad.unknown"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_unsupported_src_file_impl,
        target = name + "/bad",
        expect_failure = True,
        **kwargs
    )

def _test_unsupported_src_file_impl(env, target):
    env.expect.that_target(target).failures().contains_predicate(
        matching.contains("is misplaced here"),
    )
    env.expect.that_target(target).failures().contains_predicate(
        matching.contains("bad.unknown"),
    )

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

def _include_paths_from_argv(argv, flag):
    include_paths = []
    for i in range(len(argv) - 1):
        if argv[i] == flag:
            include_paths.append(argv[i + 1])
    return include_paths

def _system_include_paths_from_argv(argv):
    return _include_paths_from_argv(argv, "-isystem")

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

# buildifier: disable=unused-variable
def _test_external_include_paths_reclassifies_external_quote_includes(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/hello",
        srcs = ["hello.cc"],
        deps = ["@googletest//:gtest"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_external_include_paths_reclassifies_external_quote_includes_impl,
        target = name + "/hello",
        test_features = [FEATURE_NAMES.external_include_paths],
        **kwargs
    )

def _test_external_include_paths_reclassifies_external_quote_includes_impl(env, target):
    executable = target[DefaultInfo].files_to_run.executable
    link_action = env.expect.that_target(target).action_generating(executable.short_path)
    hello_obj_files = [
        f
        for f in link_action.actual.inputs.to_list()
        if f.basename.startswith("hello.") and f.extension in ["o", "obj"]
    ]

    env.expect.that_collection(hello_obj_files).has_size(1)
    compile_action = env.expect.that_target(target).action_generating(hello_obj_files[0].short_path)
    quote_include_paths = _include_paths_from_argv(compile_action.actual.argv, "-iquote")
    system_include_paths = _system_include_paths_from_argv(compile_action.actual.argv)

    if not quote_include_paths:
        fail("expected the compile action to still have non-external -iquote paths")
    env.expect.that_collection(system_include_paths).contains_predicate(
        matching.contains("googletest"),
    )
    env.expect.that_collection(quote_include_paths).transform(
        filter = matching.contains("googletest"),
    ).contains_exactly([])

def _test_linkopts_diamond(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/core",
        srcs = ["core.cc"],
        linkopts = ["-z core"],
    )
    util.helper_target(
        cc_library,
        name = name + "/lib1",
        srcs = ["lib1.cc"],
        linkopts = ["-z lib1"],
        deps = [name + "/core"],
    )
    util.helper_target(
        cc_library,
        name = name + "/lib2",
        srcs = ["lib2.cc"],
        linkopts = ["-z lib2"],
        deps = [name + "/core"],
    )
    util.helper_target(
        cc_binary,
        name = name + "/app",
        srcs = ["app.cc"],
        linkopts = ["-z app"],
        deps = [
            name + "/lib1",
            name + "/lib2",
        ],
    )
    cc_analysis_test(
        name = name,
        impl = _test_linkopts_diamond_impl,
        target = name + "/app",
        **kwargs
    )

def _test_linkopts_diamond_impl(env, target):
    link_action = link_action_subject.from_target(env, target)
    link_action.argv().contains_at_least([
        "-z",
        "app",
        "-z",
        "lib1",
        "-z",
        "lib2",
        "-z",
        "core",
    ]).in_order()

def _test_linkopts_fake_diamond(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/core1",
        srcs = ["core.cc"],
        linkopts = ["-z core"],
    )
    util.helper_target(
        cc_library,
        name = name + "/core2",
        srcs = ["core.cc"],
        linkopts = ["-z core"],
    )
    util.helper_target(
        cc_library,
        name = name + "/lib1",
        srcs = ["lib1.cc"],
        linkopts = ["-z lib1"],
        deps = [name + "/core1"],
    )
    util.helper_target(
        cc_library,
        name = name + "/lib2",
        srcs = ["lib2.cc"],
        linkopts = ["-z lib2"],
        deps = [name + "/core2"],
    )
    util.helper_target(
        cc_binary,
        name = name + "/app",
        srcs = ["app.cc"],
        linkopts = ["-z app"],
        deps = [
            name + "/lib1",
            name + "/lib2",
        ],
    )
    cc_analysis_test(
        name = name,
        impl = _test_linkopts_fake_diamond_impl,
        target = name + "/app",
        **kwargs
    )

def _test_linkopts_fake_diamond_impl(env, target):
    link_action = link_action_subject.from_target(env, target)
    link_action.argv().contains_at_least([
        "-z",
        "app",
        "-z",
        "lib1",
        "-z",
        "core",
        "-z",
        "lib2",
        "-z",
        "core",
    ]).in_order()

def _is_shared_library(path):
    basename = path.split("/")[-1]
    parts = basename.split(".")
    ext = parts[-1] if len(parts) > 1 else ""
    return ext in ["so", "dylib", "dll", "ifso"] or ".so" in basename or ".dylib" in basename

def _assert_link_staticness(env, target, expected_static):
    link_action = link_action_subject.from_target(env, target)
    shared_libs = link_action.inputs().transform(
        desc = "shared libraries",
        filter = _is_shared_library,
    )

    if expected_static:
        shared_libs.is_empty()
    else:
        shared_libs.is_not_empty()

def _create_dep_tree(name, use_actual_cc_binary = False):
    binary_rule = _actual_cc_binary if use_actual_cc_binary else cc_binary

    # Mallocs
    util.helper_target(
        cc_library,
        name = name + "/system_malloc",
        srcs = ["system_malloc.cc"],
    )
    util.helper_target(
        cc_library,
        name = name + "/mymalloc",
        srcs = ["mymalloc.cc"],
        linkopts = ["-Lmalloc_dir -lmalloc_opt"],
    )

    # Infrastructure
    util.helper_target(
        cc_library,
        name = name + "/infrastructure1",
        srcs = ["infrastructure1.cc"],
        linkopts = [
            "-Linfrastructure1_dir",
            "-linfrastructure1_opt",
        ],
        linkstamp = "linkstamp.cc",
        linkstatic = 1,
    )
    util.helper_target(
        cc_library,
        name = name + "/infrastructure2",
        srcs = ["infrastructure2.cc"],
        linkopts = ["-Linfrastructure2_dir -linfrastructure2_opt"],
        linkstamp = "linkstamp.cc",
    )

    # Middleware
    util.helper_target(
        cc_library,
        name = name + "/middleware1",
        srcs = ["middleware1.cc"],
        linkopts = [
            "-Lmiddleware1_dir",
            "-lmiddleware1_opt",
        ],
        deps = [name + "/infrastructure1"],
    )
    util.helper_target(
        binary_rule,
        name = name + "/middleware2.so",
        srcs = ["middleware2.cc"],
        linkopts = [
            "-Lmiddleware2_dir",
            "-lmiddleware2_opt",
        ],
        linkshared = 1,
        linkstatic = 1,
        deps = [name + "/infrastructure2"],
    )
    util.helper_target(
        binary_rule,
        name = name + "/middleware3.so.1",
        srcs = ["middleware3.cc"],
        linkopts = [
            "-Lmiddleware3_dir",
            "-lmiddleware3_opt",
        ],
        linkshared = 1,
        deps = [name + "/infrastructure2"],
    )

    # App
    util.helper_target(
        binary_rule,
        name = name + "/app",
        srcs = ["app.cc"],
        # Override potential default link_extra_lib attribute value
        link_extra_lib = "//tests/cc/testutil/toolchains:link_extra_lib",
        linkopts = [
            "-Lapp_dir1 -Lapp_dir2",
            "-lapp_opt",
        ],
        deps = [
            name + "/middleware1",
            name + "/middleware2.so",
            name + "/middleware3.so.1",
        ],
    )
    util.helper_target(
        binary_rule,
        name = name + "/app_nonstatic",
        srcs = ["app.cc"],
        # Override potential default link_extra_lib attribute value
        link_extra_lib = "//tests/cc/testutil/toolchains:link_extra_lib",
        linkopts = [
            "-Lapp_dir1 -Lapp_dir2",
            "-lapp_opt",
        ],
        linkstatic = 0,
        deps = [
            name + "/middleware1",
            name + "/middleware2.so",
            name + "/middleware3.so.1",
        ],
    )

# buildifier: disable=unused-variable
def _test_cc_runtimes_added_to_libraries(name, **kwargs):
    _create_dep_tree(name)
    cc_analysis_test(
        name = name,
        impl = _test_cc_runtimes_added_to_libraries_impl,
        target = name + "/app",
        test_features = [
            FEATURE_NAMES.supports_pic,
        ],
        config_settings = {
            "//command_line_option:extra_toolchains": ",".join(
                MOCK_TOOLCHAINS + [
                    "//tests/cc/common:cc_runtimes_mock_toolchain",
                ],
            ),
        },
        **kwargs
    )

def _test_cc_runtimes_added_to_libraries_impl(env, target):
    link_action = link_action_subject.from_target(env, target)
    inputs = [f.basename for f in link_action.actual.inputs.to_list()]

    env.expect.that_collection(inputs).contains_at_least([
        "app.pic.o",
        "libmiddleware1.a",
        "libinfrastructure1.a",
        "liblink_extra_lib.a",
        "libruntime.a",
        "linkstamp.o",
    ])

def _test_ignore_custom_malloc(name, **kwargs):
    _create_dep_tree(name, use_actual_cc_binary = True)
    custom_malloc_label = Label("//tests/cc/common:" + name + "/system_malloc")
    cc_analysis_test(
        name = name,
        impl = _test_ignore_custom_malloc_impl,
        target = name + "/app",
        config_settings = {
            "//command_line_option:custom_malloc": custom_malloc_label,
        },
        **kwargs
    )

def _test_ignore_custom_malloc_impl(env, target):
    link_action = link_action_subject.from_target(env, target)
    inputs = [f.basename for f in link_action.actual.inputs.to_list()]
    env.expect.that_collection(inputs).contains("libsystem_malloc.a")
    env.expect.that_collection(inputs).not_contains("libmock_malloc.a")

def _test_custom_malloc(name, **kwargs):
    _create_dep_tree(name, use_actual_cc_binary = True)
    custom_malloc_label = Label("//tests/cc/common:" + name + "/mymalloc")
    cc_analysis_test(
        name = name,
        impl = _test_custom_malloc_impl,
        target = name + "/app",
        test_features = [FEATURE_NAMES.supports_pic],
        config_settings = {
            "//command_line_option:custom_malloc": custom_malloc_label,
        },
        **kwargs
    )

def _test_custom_malloc_impl(env, target):
    link_action = link_action_subject.from_target(env, target)
    inputs = [f.basename for f in link_action.actual.inputs.to_list()]
    env.expect.that_collection(inputs).contains("libmymalloc.a")
    env.expect.that_collection(inputs).not_contains("libmock_malloc.a")

CcRuntimesInfo = provider(
    doc = "Information about runtime libraries to link into c++ targets.",
    fields = ["runtimes", "copts"],
)

def _test_app_linking_static(name, **kwargs):
    _create_dep_tree(name)
    cc_analysis_test(
        name = name,
        impl = _test_app_linking_static_impl,
        target = name + "/app",
        test_features = [
            FEATURE_NAMES.supports_pic,
            FEATURE_NAMES.supports_dynamic_linker,
            FEATURE_NAMES.supports_interface_shared_libraries,
        ],
        **kwargs
    )

def _test_app_linking_static_impl(env, target):
    link_action = link_action_subject.from_target(env, target)
    inputs = [f.basename for f in link_action.actual.inputs.to_list()]

    # Assert inputs
    env.expect.that_collection(inputs).contains("app.pic.o")
    env.expect.that_collection(inputs).contains("libmiddleware1.a")
    env.expect.that_collection(inputs).contains("libinfrastructure1.a")
    env.expect.that_collection(inputs).contains("linkstamp.o")

    # Assert NOT inputs
    env.expect.that_collection(inputs).not_contains("libinfrastructure2.a")
    env.expect.that_collection(inputs).not_contains("libmiddleware2.so")
    env.expect.that_collection(inputs).not_contains("libmiddleware3.so.1")

    # Assert linkopts
    link_action.argv().contains_at_least([
        "-Lapp_dir1",
        "-Lapp_dir2",
        "-lapp_opt",
        "-Lmiddleware1_dir",
        "-lmiddleware1_opt",
        "-Linfrastructure1_dir",
        "-linfrastructure1_opt",
    ]).in_order()

def _test_app_linking_dynamic(name, **kwargs):
    _create_dep_tree(name)
    cc_analysis_test(
        name = name,
        impl = _test_app_linking_dynamic_impl,
        target = name + "/app_nonstatic",
        test_features = [
            FEATURE_NAMES.supports_pic,
            FEATURE_NAMES.supports_dynamic_linker,
            FEATURE_NAMES.supports_interface_shared_libraries,
        ],
        **kwargs
    )

def _test_app_linking_dynamic_impl(env, target):
    link_action = link_action_subject.from_target(env, target)
    inputs = [f.basename for f in link_action.actual.inputs.to_list()]

    # Assert inputs
    env.expect.that_collection(inputs).contains("app.pic.o")
    env.expect.that_collection(inputs).contains("libinfrastructure1.a")
    env.expect.that_collection(inputs).contains("linkstamp.o")

    # Assert dynamic library symlink (mangled)
    env.expect.that_collection(inputs).contains_predicate(
        matching.str_endswith("_Slibmiddleware1.ifso"),
    )

    # Assert NOT inputs
    env.expect.that_collection(inputs).not_contains("libmiddleware1.a")
    env.expect.that_collection(inputs).not_contains("libinfrastructure2.a")

    # Assert linkopts
    link_action.argv().contains_at_least([
        "-Lapp_dir1",
        "-Lapp_dir2",
        "-lapp_opt",
        "-Lmiddleware1_dir",
        "-lmiddleware1_opt",
        "-Linfrastructure1_dir",
        "-linfrastructure1_opt",
    ]).in_order()

def _test_compilation_prerequisites_in_output_group(name, **kwargs):
    out_file = name + "_a.cc"
    util.helper_target(
        native.genrule,
        name = name + "/gen",
        outs = [out_file],
        cmd = "echo '' > $@",
    )
    util.helper_target(
        cc_library,
        name = name + "/mylib",
        hdrs = ["b.h"],
    )
    util.helper_target(
        cc_binary,
        name = name + "/prerequisites",
        srcs = [
            name + "/gen",
            "hello.cc",
            "hello.h",
        ],
        deps = [name + "/mylib"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_compilation_prerequisites_in_output_group_impl,
        target = name + "/prerequisites",
        attrs = {
            "out_file": attr.string(),
        },
        attr_values = {
            "out_file": out_file,
        },
        **kwargs
    )

def _test_compilation_prerequisites_in_output_group_impl(env, target):
    prereqs = target[OutputGroupInfo].compilation_prerequisites_INTERNAL_.to_list()
    prereq_paths = [f.short_path for f in prereqs]
    target_subject = env.expect.that_target(target)
    prereqs_subject = subjects.collection(
        prereq_paths,
        meta = target_subject.meta.derive("compilation_prerequisites"),
        format = True,
    )

    prereqs_subject.contains("{package}/hello.cc")
    prereqs_subject.contains("{package}/hello.h")
    prereqs_subject.contains("{package}/b.h")

    out_file = env.ctx.attr.out_file
    prereqs_subject.contains("{package}/" + out_file)
    prereqs_subject.contains_predicate(matching.str_endswith("cppmap"))

def _create_prefers_pic_libs_dep_tree(name):
    util.helper_target(
        cc_library,
        name = name + "/mylib",
        srcs = ["dep.pic.a", "dep.nopic.a"],
    )
    util.helper_target(
        cc_binary,
        name = name + "/mybinary",
        srcs = ["mybinary.cc"],
        deps = [name + "/mylib"],
    )

def _test_pic_mode_prefers_pic_libs_force_pic_disabled(name, **kwargs):
    _create_prefers_pic_libs_dep_tree(name)
    cc_analysis_test(
        name = name,
        impl = _test_pic_mode_prefers_pic_libs_force_pic_disabled_impl,
        target = name + "/mybinary",
        test_features = [FEATURE_NAMES.supports_pic],
        config_settings = {
            "//command_line_option:force_pic": False,
        },
        **kwargs
    )

def _test_pic_mode_prefers_pic_libs_force_pic_disabled_impl(env, target):
    link_action = link_action_subject.from_target(env, target)
    inputs = [f.basename for f in link_action.actual.inputs.to_list()]
    env.expect.that_collection(inputs).contains("dep.nopic.a")
    env.expect.that_collection(inputs).not_contains("dep.pic.a")

def _test_pic_mode_prefers_pic_libs_force_pic_enabled(name, **kwargs):
    _create_prefers_pic_libs_dep_tree(name)
    cc_analysis_test(
        name = name,
        impl = _test_pic_mode_prefers_pic_libs_force_pic_enabled_impl,
        target = name + "/mybinary",
        test_features = [FEATURE_NAMES.supports_pic],
        config_settings = {
            "//command_line_option:force_pic": True,
        },
        **kwargs
    )

def _test_pic_mode_prefers_pic_libs_force_pic_enabled_impl(env, target):
    link_action = link_action_subject.from_target(env, target)
    inputs = [f.basename for f in link_action.actual.inputs.to_list()]
    env.expect.that_collection(inputs).contains("dep.pic.a")
    env.expect.that_collection(inputs).not_contains("dep.nopic.a")

def _test_pic_mode_uses_pic_libs(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/mylib",
        srcs = ["dep.pic.o"],
    )
    util.helper_target(
        cc_binary,
        name = name + "/mybinary",
        srcs = ["mybinary.cc"],
        deps = [name + "/mylib"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_pic_mode_uses_pic_libs_impl,
        target = name + "/mybinary",
        test_features = [
            FEATURE_NAMES.supports_pic,
            FEATURE_NAMES.supports_start_end_lib,
        ],
        config_settings = {
            "//command_line_option:force_pic": True,
        },
        **kwargs
    )

def _test_pic_mode_uses_pic_libs_impl(env, target):
    link_action = link_action_subject.from_target(env, target)
    inputs = [f.basename for f in link_action.actual.inputs.to_list()]
    env.expect.that_collection(inputs).contains("dep.pic.o")

def _create_does_not_use_nopic_library_dep_tree(name):
    util.helper_target(
        cc_library,
        name = name + "/mylib",
        srcs = ["dep.nopic.o"],
    )
    util.helper_target(
        cc_binary,
        name = name + "/mybinary",
        srcs = ["mybinary.cc"],
        deps = [name + "/mylib"],
    )

def _test_pic_mode_does_not_use_nopic_library_force_pic_disabled(name, **kwargs):
    _create_does_not_use_nopic_library_dep_tree(name)
    cc_analysis_test(
        name = name,
        impl = _test_pic_mode_does_not_use_nopic_library_force_pic_disabled_impl,
        target = name + "/mybinary",
        test_features = [FEATURE_NAMES.supports_pic],
        config_settings = {
            "//command_line_option:force_pic": False,
        },
        **kwargs
    )

def _test_pic_mode_does_not_use_nopic_library_force_pic_disabled_impl(env, target):
    link_action = link_action_subject.from_target(env, target)
    inputs = [f.basename for f in link_action.actual.inputs.to_list()]
    env.expect.that_collection(inputs).contains("mybinary.pic.o")
    env.expect.that_collection(inputs).not_contains("dep.nopic.o")

def _test_pic_mode_does_not_use_nopic_library_force_pic_enabled(name, **kwargs):
    _create_does_not_use_nopic_library_dep_tree(name)
    cc_analysis_test(
        name = name,
        impl = _test_pic_mode_does_not_use_nopic_library_force_pic_enabled_impl,
        target = name + "/mybinary",
        test_features = [FEATURE_NAMES.supports_pic],
        config_settings = {
            "//command_line_option:force_pic": True,
        },
        **kwargs
    )

def _test_pic_mode_does_not_use_nopic_library_force_pic_enabled_impl(env, target):
    link_action = link_action_subject.from_target(env, target)
    inputs = [f.basename for f in link_action.actual.inputs.to_list()]
    env.expect.that_collection(inputs).not_contains("dep.nopic.o")

def _test_pic_mode_does_not_use_nopic_binary(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/mybinary",
        srcs = ["xyz.nopic.o"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_pic_mode_does_not_use_nopic_binary_impl,
        target = name + "/mybinary",
        test_features = [FEATURE_NAMES.supports_pic],
        **kwargs
    )

def _test_pic_mode_does_not_use_nopic_binary_impl(env, target):
    link_action = link_action_subject.from_target(env, target)
    inputs = [f.basename for f in link_action.actual.inputs.to_list()]
    env.expect.that_collection(inputs).not_contains("xyz.nopic.o")

def _cc_runtimes_toolchain_impl(ctx):
    return [platform_common.ToolchainInfo(
        cc_runtimes_info = CcRuntimesInfo(
            runtimes = ctx.attr.runtimes,
            copts = ctx.attr.copts,
        ),
    )]

_cc_runtimes_toolchain = rule(
    implementation = _cc_runtimes_toolchain_impl,
    attrs = {
        "runtimes": attr.label_list(),
        "copts": attr.string_list(),
    },
)

def _mock_runtime_library_impl(ctx):
    lib_file = ctx.actions.declare_file("lib" + ctx.label.name + ".a")
    ctx.actions.write(output = lib_file, content = "mock archive content")
    library_to_link = cc_common.create_library_to_link(
        actions = ctx.actions,
        static_library = lib_file,
    )
    linker_input = cc_common.create_linker_input(
        libraries = depset([library_to_link]),
        owner = ctx.label,
    )
    linking_context = cc_common.create_linking_context(
        linker_inputs = depset([linker_input]),
    )
    return [
        CcInfo(linking_context = linking_context),
        DefaultInfo(files = depset([lib_file])),
    ]

_mock_runtime_library = rule(
    implementation = _mock_runtime_library_impl,
    attrs = {},
)

def _setup_cc_runtimes_mock():
    util.helper_target(
        _mock_runtime_library,
        name = "runtime",
    )

    util.helper_target(
        _cc_runtimes_toolchain,
        name = "runtimes_toolchain",
        copts = ["-Iruntimes"],
        runtimes = [":runtime"],
    )

    native.toolchain(
        name = "cc_runtimes_mock_toolchain",
        toolchain = ":runtimes_toolchain",
        toolchain_type = Label("@bazel_tools//tools/cpp:cc_runtimes_toolchain_type"),
        tags = ["manual", "notap"],
    )

def _register_link_staticness_test(name, target_under_test, expected_static, config_settings = {}, with_features = [], **kwargs):
    config_settings = dict(
        {
            # Apple builds do not support statically linked binaries so we force the target platform
            # to Linux. TODO: Do we want to test this separately for Windows targets?
            # Note: Already the previous Java tests set --cpu=k8 for these tests.
            "//command_line_option:platforms": [Label("//tests/cc/testutil:linux_x86_64")],
        },
        **config_settings
    )
    cc_analysis_test(
        name = name,
        impl = _link_staticness_test_impl,
        target = target_under_test,
        config_settings = config_settings,
        with_features = with_features,
        attrs = {
            "expected_static": attr.bool(),
        },
        attr_values = {
            "expected_static": expected_static,
        },
        **kwargs
    )

def _link_staticness_test_impl(env, target):
    _assert_link_staticness(env, target, env.ctx.attr.expected_static)

def _create_link_staticness_dep_tree(name):
    util.helper_target(
        cc_library,
        name = name + "/dep",
        srcs = ["dep.cc"],
    )
    util.helper_target(
        cc_binary,
        name = name + "/hello",
        srcs = ["hello.cc"],
        deps = [name + "/dep"],
        linkopts = ["-static"],
    )
    util.helper_target(
        cc_test,
        name = name + "/hello_test",
        srcs = ["hello.cc", "hello_test.cc"],
        deps = [name + "/dep"],
    )
    util.helper_target(
        cc_test,
        name = name + "/hello_test2",
        srcs = ["hello.cc", "hello_test.cc"],
        deps = [name + "/dep"],
        linkstatic = 1,
    )

# Default Config Suite
def _test_link_staticness_hello_default(name, **kwargs):
    _create_link_staticness_dep_tree(name)
    _register_link_staticness_test(
        name = name,
        target_under_test = name + "/hello",
        expected_static = True,
        config_settings = {
            "//command_line_option:dynamic_mode": "default",
        },
        with_features = [FEATURE_NAMES.supports_pic, FEATURE_NAMES.supports_dynamic_linker],
        **kwargs
    )

def _test_link_staticness_hello_test_default(name, **kwargs):
    _create_link_staticness_dep_tree(name)
    _register_link_staticness_test(
        name = name,
        target_under_test = name + "/hello_test",
        expected_static = False,
        config_settings = {
            "//command_line_option:dynamic_mode": "default",
        },
        with_features = [FEATURE_NAMES.supports_pic, FEATURE_NAMES.supports_dynamic_linker],
        **kwargs
    )

def _test_link_staticness_hello_test2_default(name, **kwargs):
    _create_link_staticness_dep_tree(name)
    _register_link_staticness_test(
        name = name,
        target_under_test = name + "/hello_test2",
        expected_static = True,
        config_settings = {
            "//command_line_option:dynamic_mode": "default",
        },
        with_features = [FEATURE_NAMES.supports_pic, FEATURE_NAMES.supports_dynamic_linker],
        **kwargs
    )

# Off Config Suite
def _test_link_staticness_hello_off(name, **kwargs):
    _create_link_staticness_dep_tree(name)
    _register_link_staticness_test(
        name = name,
        target_under_test = name + "/hello",
        expected_static = True,
        config_settings = {
            "//command_line_option:dynamic_mode": "off",
        },
        with_features = [FEATURE_NAMES.supports_pic, FEATURE_NAMES.supports_dynamic_linker],
        **kwargs
    )

def _test_link_staticness_hello_test_off(name, **kwargs):
    _create_link_staticness_dep_tree(name)
    _register_link_staticness_test(
        name = name,
        target_under_test = name + "/hello_test",
        expected_static = True,
        config_settings = {
            "//command_line_option:dynamic_mode": "off",
        },
        with_features = [FEATURE_NAMES.supports_pic, FEATURE_NAMES.supports_dynamic_linker],
        **kwargs
    )

def _test_link_staticness_hello_test2_off(name, **kwargs):
    _create_link_staticness_dep_tree(name)
    _register_link_staticness_test(
        name = name,
        target_under_test = name + "/hello_test2",
        expected_static = True,
        config_settings = {
            "//command_line_option:dynamic_mode": "off",
        },
        with_features = [FEATURE_NAMES.supports_pic, FEATURE_NAMES.supports_dynamic_linker],
        **kwargs
    )

# Fully Config Suite
def _test_link_staticness_hello_fully(name, **kwargs):
    _create_link_staticness_dep_tree(name)
    _register_link_staticness_test(
        name = name,
        target_under_test = name + "/hello",
        expected_static = False,
        config_settings = {
            "//command_line_option:dynamic_mode": "fully",
        },
        with_features = [FEATURE_NAMES.supports_pic, FEATURE_NAMES.supports_dynamic_linker],
        **kwargs
    )

def _test_link_staticness_hello_test_fully(name, **kwargs):
    _create_link_staticness_dep_tree(name)
    _register_link_staticness_test(
        name = name,
        target_under_test = name + "/hello_test",
        expected_static = False,
        config_settings = {
            "//command_line_option:dynamic_mode": "fully",
        },
        with_features = [FEATURE_NAMES.supports_pic, FEATURE_NAMES.supports_dynamic_linker],
        **kwargs
    )

def _test_link_staticness_hello_test2_fully(name, **kwargs):
    _create_link_staticness_dep_tree(name)
    _register_link_staticness_test(
        name = name,
        target_under_test = name + "/hello_test2",
        expected_static = False,
        config_settings = {
            "//command_line_option:dynamic_mode": "fully",
        },
        with_features = [FEATURE_NAMES.supports_pic, FEATURE_NAMES.supports_dynamic_linker],
        **kwargs
    )

def _create_linking_mode_features_dep_tree(name):
    util.helper_target(
        cc_binary,
        name = name + "/linkstatic_true",
        srcs = ["binary.cc"],
    )
    util.helper_target(
        cc_binary,
        name = name + "/linkstatic_false",
        srcs = ["binary.cc"],
        linkstatic = 0,
    )

def _register_linking_mode_features_test(name, target_under_test, expected_mode, config_settings = {}, **kwargs):
    config_settings = dict(
        {
            # Windows does not support linking_mode features so we force the target platform to
            # Linux. TODO: Do we want to test this separately for Apple targets?
            "//command_line_option:platforms": [Label("//tests/cc/testutil:linux_x86_64")],
        },
        **config_settings
    )
    cc_analysis_test(
        name = name,
        impl = _linking_mode_features_test_impl,
        target = target_under_test,
        config_settings = config_settings,
        with_features = [
            FEATURE_NAMES.static_linking_mode,
            FEATURE_NAMES.dynamic_linking_mode,
            FEATURE_NAMES.supports_dynamic_linker,
        ],
        attrs = {
            "expected_mode": attr.string(),
        },
        attr_values = {
            "expected_mode": expected_mode,
        },
        **kwargs
    )

def _linking_mode_features_test_impl(env, target):
    link_action = link_action_subject.from_target(env, target)
    link_action.env().get("linking_mode", factory = subjects.str).equals(env.ctx.attr.expected_mode)

# Default Config
def _test_linking_mode_features_true_default(name, **kwargs):
    _create_linking_mode_features_dep_tree(name)
    _register_linking_mode_features_test(name, name + "/linkstatic_true", "static", **kwargs)

def _test_linking_mode_features_false_default(name, **kwargs):
    _create_linking_mode_features_dep_tree(name)
    _register_linking_mode_features_test(name, name + "/linkstatic_false", "dynamic", **kwargs)

# Fully Config
def _test_linking_mode_features_true_fully(name, **kwargs):
    _create_linking_mode_features_dep_tree(name)
    _register_linking_mode_features_test(
        name,
        name + "/linkstatic_true",
        "dynamic",
        config_settings = {"//command_line_option:dynamic_mode": "fully"},
        **kwargs
    )

def _test_linking_mode_features_false_fully(name, **kwargs):
    _create_linking_mode_features_dep_tree(name)
    _register_linking_mode_features_test(
        name,
        name + "/linkstatic_false",
        "dynamic",
        config_settings = {"//command_line_option:dynamic_mode": "fully"},
        **kwargs
    )

# Off Config
def _test_linking_mode_features_true_off(name, **kwargs):
    _create_linking_mode_features_dep_tree(name)
    _register_linking_mode_features_test(
        name,
        name + "/linkstatic_true",
        "static",
        config_settings = {"//command_line_option:dynamic_mode": "off"},
        **kwargs
    )

def _test_linking_mode_features_false_off(name, **kwargs):
    _create_linking_mode_features_dep_tree(name)
    _register_linking_mode_features_test(
        name,
        name + "/linkstatic_false",
        "static",
        config_settings = {"//command_line_option:dynamic_mode": "off"},
        **kwargs
    )

# Regression test for b/157471662.
def _test_link_shared_does_not_have_to_provide_extension(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/foo",
        srcs = ["foo.cc"],
        linkshared = 1,
    )
    cc_analysis_test(
        name = name,
        impl = _test_link_shared_does_not_have_to_provide_extension_impl,
        target = name + "/foo",
        **kwargs
    )

def _test_link_shared_does_not_have_to_provide_extension_impl(env, target):
    executable = target[DefaultInfo].files_to_run.executable
    env.expect.that_str(executable.basename).equals("libfoo.so")

def cc_binary_configured_target_tests(name):
    """Creates the test suite for cc_binary tests.

    Args:
        name: The name of the test suite.
    """
    tests = [
        _test_files_to_build,
        _test_headers_not_passed_to_linking_action,
        _test_no_duplicate_linkopts,
        _test_action_graph,
        _test_runtime_dynamic_libraries_copy_behavior,
        _test_pic,
        _test_duplicate_linkopts,
        _test_unsupported_src_file,
        _test_missing_action_config_for_strip_is_a_rule_error,
        _test_linkopts_diamond,
        _test_linkopts_fake_diamond,
        _test_app_linking_static,
        _test_app_linking_dynamic,
        _test_compilation_prerequisites_in_output_group,
        _test_pic_mode_prefers_pic_libs_force_pic_disabled,
        _test_pic_mode_prefers_pic_libs_force_pic_enabled,
        _test_pic_mode_uses_pic_libs,
        _test_pic_mode_does_not_use_nopic_library_force_pic_disabled,
        _test_pic_mode_does_not_use_nopic_library_force_pic_enabled,
        _test_pic_mode_does_not_use_nopic_binary,
        _test_ignore_custom_malloc,
        _test_custom_malloc,
        _test_link_shared_does_not_have_to_provide_extension,
    ]

    # sanitize_pwd is implemented in Starlark in rules_cc, requires Bazel 9+.
    if bazel_features.cc.cc_common_is_in_rules_cc:
        _setup_cc_runtimes_mock()
        tests.extend([
            _test_sanitize_pwd_feature_enabled,
            _test_sanitize_pwd_feature_disabled,
            _test_sanitize_pwd_macos_no_pwd,
            _test_external_include_paths_reclassifies_external_quote_includes,  # copybara-uncomment-this-please
            _test_system_include_paths_reclassifies_local_includes_after_includes,
            _test_system_include_paths_reclassifies_local_includes_without_propagation,
            _test_generated_def_file_uses_toolchain_action,  # copybara-uncomment-this-please
            _test_generated_def_file_uses_default_tool,  # copybara-uncomment-this-please
            _test_link_staticness_hello_default,
            _test_link_staticness_hello_test_default,
            _test_link_staticness_hello_test2_default,
            _test_link_staticness_hello_off,
            _test_link_staticness_hello_test_off,
            _test_link_staticness_hello_test2_off,
            _test_link_staticness_hello_fully,
            _test_link_staticness_hello_test_fully,
            _test_link_staticness_hello_test2_fully,
            _test_linking_mode_features_true_default,
            _test_linking_mode_features_false_default,
            _test_linking_mode_features_true_fully,
            _test_linking_mode_features_false_fully,
            _test_linking_mode_features_true_off,
            _test_linking_mode_features_false_off,
            # _test_cc_runtimes_added_to_libraries,  # copybara-comment-this-out-please
        ])

    test_suite(
        name = name,
        tests = tests,
    )
