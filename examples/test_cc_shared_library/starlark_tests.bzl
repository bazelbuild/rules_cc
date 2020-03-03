"""Starlark tests for cc_shared_library"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts", "unittest")
load("//examples:experimental_cc_shared_library.bzl", "for_testing_dont_use_check_if_target_under_path")

def _linking_suffix_test_impl(ctx):
    env = analysistest.begin(ctx)

    target_under_test = analysistest.target_under_test(env)
    actions = analysistest.target_actions(env)

    for arg in reversed(actions[1].argv):
        if arg.find(".a") != -1 or arg.find("-l") != -1:
            asserts.equals(env, "libbar4.a", arg[arg.rindex("/") + 1:])
            break

    return analysistest.end(env)

linking_suffix_test = analysistest.make(_linking_suffix_test_impl)

def _additional_inputs_test_impl(ctx):
    env = analysistest.begin(ctx)

    target_under_test = analysistest.target_under_test(env)
    actions = analysistest.target_actions(env)

    found = False
    for arg in actions[1].argv:
        if arg.find("-Wl,--script=") != -1:
            asserts.equals(env, "examples/test_cc_shared_library/additional_script.txt", arg[13:])
            found = True
            break
    asserts.true(env, found, "Should have seen option --script=")

    return analysistest.end(env)

additional_inputs_test = analysistest.make(_additional_inputs_test_impl)

def _link_once_repeated_test_impl(ctx):
    env = analysistest.begin(ctx)

    asserts.expect_failure(env, "already linked statically")

    return analysistest.end(env)

link_once_repeated_test = analysistest.make(_link_once_repeated_test_impl, expect_failure = True)

def _paths_test_impl(ctx):
    env = unittest.begin(ctx)

    asserts.false(env, for_testing_dont_use_check_if_target_under_path(Label("//foo"), Label("//bar")))
    asserts.false(env, for_testing_dont_use_check_if_target_under_path(Label("@foo//foo"), Label("@bar//bar")))
    asserts.false(env, for_testing_dont_use_check_if_target_under_path(Label("//bar"), Label("@foo//bar")))
    asserts.true(env, for_testing_dont_use_check_if_target_under_path(Label("@foo//bar"), Label("@foo//bar")))
    asserts.true(env, for_testing_dont_use_check_if_target_under_path(Label("@foo//bar:bar"), Label("@foo//bar")))
    asserts.true(env, for_testing_dont_use_check_if_target_under_path(Label("//bar:bar"), Label("//bar")))

    asserts.false(env, for_testing_dont_use_check_if_target_under_path(Label("@foo//bar/baz"), Label("@foo//bar")))
    asserts.false(env, for_testing_dont_use_check_if_target_under_path(Label("@foo//bar/baz"), Label("@foo//bar:__pkg__")))
    asserts.true(env, for_testing_dont_use_check_if_target_under_path(Label("@foo//bar/baz"), Label("@foo//bar:__subpackages__")))
    asserts.true(env, for_testing_dont_use_check_if_target_under_path(Label("@foo//bar:qux"), Label("@foo//bar:__pkg__")))

    asserts.false(env, for_testing_dont_use_check_if_target_under_path(Label("@foo//bar"), Label("@foo//bar/baz:__subpackages__")))
    asserts.false(env, for_testing_dont_use_check_if_target_under_path(Label("//bar"), Label("//bar/baz:__pkg__")))

    return unittest.end(env)

paths_test = unittest.make(_paths_test_impl)
