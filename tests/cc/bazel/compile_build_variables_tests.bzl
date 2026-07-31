"""Bazel-only tests for compile build variables."""

load("@rules_testing//lib:analysis_test.bzl", "test_suite")
load("@rules_testing//lib:util.bzl", "TestingAspectInfo", "util")
load("//cc:cc_binary.bzl", "cc_binary")
load("//cc:cc_library.bzl", "cc_library")
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test")

def _compile_action(env, target, name):
    return env.expect.that_target(target).action_generating(
        "{package}/_objs/{name}/" + name + ".o",
    )

def _variable_list(action, name):
    prefix = "--debug-var:{}=".format(name)
    return action.argv().transform(
        desc = "values of variable " + name,
        filter = lambda arg: arg.startswith(prefix),
        map_each = lambda arg: arg[len(prefix):],
    )

def _test_external_include_paths_variable(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/local_bar",
        hdrs = ["header.h"],
    )
    util.helper_target(
        cc_binary,
        name = name + "/bin",
        srcs = ["bin.cc"],
        deps = [
            name + "/local_bar",
            "@cross_repo_test//bazel_test_includes:bar",  # copybara-uncomment-this-please
            "@cross_repo_test//bazel_test_includes:bar_virtual",  # copybara-uncomment-this-please
        ],
    )
    cc_analysis_test(
        name = name,
        impl = _test_external_include_paths_variable_impl,
        target = name + "/bin",
        test_features = ["external_include_paths"],
        **kwargs
    )

def _test_external_include_paths_variable_impl(env, target):
    deps = target[TestingAspectInfo].attrs.deps
    pkg_repo_name = None
    for dep in deps:
        if dep.label.package == "bazel_test_includes" and dep.label.name == "bar":
            pkg_repo_name = dep.label.workspace_name
            break
    if not pkg_repo_name:
        fail("Could not find @cross_repo_test dependency")

    bin_path = target[TestingAspectInfo].bin_path

    compile_action = _compile_action(env, target, "bin")
    _variable_list(compile_action, "external_include_paths").contains_at_least([
        # buildifier: disable=external-path
        "{bin_path}/external/{repo}/bazel_test_includes/_virtual_includes/bar_virtual".format(
            bin_path = bin_path,
            repo = pkg_repo_name,
        ),
        # buildifier: disable=external-path
        "external/{repo}".format(repo = pkg_repo_name),
        # buildifier: disable=external-path
        "{bin_path}/external/{repo}".format(
            bin_path = bin_path,
            repo = pkg_repo_name,
        ),
    ])

def compile_build_variables_tests(name, **kwargs):
    test_suite(
        name = name,
        tests = [
            _test_external_include_paths_variable,
        ],
        **kwargs
    )
