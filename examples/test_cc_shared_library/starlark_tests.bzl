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
