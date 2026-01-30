load("@bazel_skylib//lib:unittest.bzl", "asserts", "analysistest")
load("@rules_cc//cc:defs.bzl","cc_library","cc_binary")
load("@rules_cc//cc/common:debug_package_info.bzl","DebugPackageInfo")
load("@bazel_skylib//lib:new_sets.bzl", "sets")
load("@bazel_features//private:util.bzl", _bazel_version_ge = "ge")

def _dwo_files_contents(ctx):
    env = analysistest.begin(ctx)

    target_under_test = analysistest.target_under_test(env)
    file_names = sets.make([f.short_path for f in target_under_test[DebugPackageInfo].dwo_files.to_list()])
    asserts.set_equals(env,sets.make([
        "tests/debug_files/_objs/lib/lib.dwo",
        "tests/debug_files/_objs/impl_lib/impl_lib.dwo",
        "tests/debug_files/_objs/main/main.dwo"]),file_names)

    return analysistest.end(env)

def _dwo_files_no_contents(ctx):
    env = analysistest.begin(ctx)

    target_under_test = analysistest.target_under_test(env)
    asserts.equals(env,[],target_under_test[DebugPackageInfo].dwo_files.to_list())

    return analysistest.end(env)

dwo_files_contents_test = analysistest.make(_dwo_files_contents,
config_settings = {
    "//command_line_option:fission": "yes",
    "//command_line_option:features": ["per_object_debug_info"],
},)

dwo_files_no_contents_test = analysistest.make(_dwo_files_no_contents,
config_settings = {
    "//command_line_option:fission": "no",
})

def _test_provider_contents():
    cc_library(
        name = "impl_lib",
        hdrs = ["impl_lib.h"],
        srcs = ["impl_lib.cc"],
    )

    cc_library(
        name = "lib",
        hdrs = ["lib.h"],
        srcs = ["lib.cc"],
        implementation_deps = [":impl_lib"],
    )

    cc_binary(
        name = "main",
        srcs = ["main.cc"],
        deps  = ["lib"],

    )

    dwo_files_contents_test(name = "dwo_files_content_test",
                           target_under_test = ":main")
    dwo_files_no_contents_test(name = "dwo_files_no_content_test",
                                                  target_under_test = ":main")

def dwo_files_test_suite(name):
    if _bazel_version_ge("9.0.0-pre.20250911"):
        # we only test this if we are on a version where
        # the DebugPackageInfo provider is defined by rules_cc
        # and not bazel.
        _test_provider_contents()

        native.test_suite(
            name = name,
            tests = [
                ":dwo_files_content_test",
                ":dwo_files_no_content_test",
            ],
        )
