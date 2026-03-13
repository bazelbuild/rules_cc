"""Tests for cc_binary."""

load("@rules_testing//lib:analysis_test.bzl", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching")
load("@rules_testing//lib:util.bzl", "util")
load("//cc:cc_binary.bzl", "cc_binary")
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test")
load("//tests/cc/testutil:cc_binary_target_subject.bzl", "cc_binary_target_subject")
load("//tests/cc/testutil:link_action_subject.bzl", "link_action_subject")

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

def cc_binary_configured_target_tests(name):
    test_suite(
        name = name,
        tests = [
            _test_files_to_build,
            _test_headers_not_passed_to_linking_action,
            _test_no_duplicate_linkopts,
            _test_action_graph,
        ],
    )
