"""Starlark tests for cc_shared_library"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

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
