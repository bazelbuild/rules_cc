"""Unit tests for cxx_standard flags."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//cc:cc_binary.bzl", "cc_binary")
load("//cc/cxx_standard:cxx_standard.bzl", "cxxopts")

def _get_compile_action(target):
    """Get the C++ compile action from a target."""
    for action in target.actions:
        if action.mnemonic == "CppCompile":
            return action
    fail("No CppCompile action found")

def _extract_flags_between_markers(argv):
    """Extract flags between BEGIN and END markers."""
    begin_marker = "-DRULES_CC_STD_CXX_TEST_BEGIN"
    end_marker = "-DRULES_CC_STD_CXX_TEST_END"

    begin_idx = -1
    end_idx = -1

    for i, arg in enumerate(argv):
        if arg == begin_marker:
            begin_idx = i
        elif arg == end_marker:
            end_idx = i
            break

    if begin_idx == -1 or end_idx == -1:
        return []

    return argv[begin_idx + 1:end_idx]

def _cxx_flag_test_common_impl(ctx, version, inclusive):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    action = _get_compile_action(tut)

    flags_between_markers = _extract_flags_between_markers(action.argv)
    expected_flag = "-std=c++{}".format(version)

    if inclusive:
        asserts.true(
            env,
            expected_flag in flags_between_markers,
            "Expected flag '{}' between markers, got: {}".format(expected_flag, flags_between_markers),
        )
    else:
        asserts.true(
            env,
            expected_flag not in flags_between_markers,
            "Unexpected flag '{}' between markers, got: {}".format(expected_flag, flags_between_markers),
        )
    return analysistest.end(env)

def _cxx_default_flag_test_impl(ctx):
    return _cxx_flag_test_common_impl(ctx, ctx.attr.version, True)

def _cxx_no_flag_test_impl(ctx):
    return _cxx_flag_test_common_impl(ctx, ctx.attr.version, False)

cxx_default_flag_test = analysistest.make(
    _cxx_default_flag_test_impl,
    doc = "A test that confirms the default provided to the `cxxopts` macro is used for compilation.",
    attrs = {
        "version": attr.string(doc = "The cxx version", mandatory = True),
    },
    config_settings = {
        str(Label("//cc/cxx_standard:cxx_standard")): "default",
    },
)

cxx_no_flag_test = analysistest.make(
    _cxx_no_flag_test_impl,
    doc = "A test that force disables flags from the `cxxopts` macro regardless of any default specified.",
    attrs = {
        "version": attr.string(doc = "The cxx version", mandatory = True),
    },
    config_settings = {
        str(Label("//cc/cxx_standard:cxx_standard")): "none",
    },
)

def _cxx_forced_17_flag_test_impl(ctx):
    return _cxx_flag_test_common_impl(ctx, "17", True)

cxx_forced_17_flag_test = analysistest.make(
    _cxx_forced_17_flag_test_impl,
    doc = "A test that forces `cxx17` regardless of any default specified to the `cxxopts` macro.",
    config_settings = {
        str(Label("//cc/cxx_standard:cxx_standard")): "17",
    },
)

def _cxx_forced_20_flag_test_impl(ctx):
    return _cxx_flag_test_common_impl(ctx, "20", True)

cxx_forced_20_flag_test = analysistest.make(
    _cxx_forced_20_flag_test_impl,
    doc = "A test that forces `cxx20` regardless of any default specified to the `cxxopts` macro.",
    config_settings = {
        str(Label("//cc/cxx_standard:cxx_standard")): "20",
    },
)

def _cxx_std_test():
    """Helper function to create test targets."""
    tests = []
    for version in ["98", "03", "11", "14", "17", "20", "23", "26", "2c"]:
        target_under_test = "test_bin_{}".format(version)
        cc_binary(
            name = target_under_test,
            srcs = ["main.cc"],
            # To identify the specific instance of the macros stdcxx flag, the arguments are wrapped
            # in some identifier flags so we can know when the flag is or isn't acutally produced.
            copts = ["-DRULES_CC_STD_CXX_TEST_BEGIN"] + cxxopts(default = version) + ["-DRULES_CC_STD_CXX_TEST_END"],
        )

        test_name = "cxx{}_default_flag_test".format(version)
        tests.append(test_name)
        cxx_default_flag_test(
            name = test_name,
            target_under_test = ":" + target_under_test,
            version = version,
        )

        test_name = "cxx{}_no_flag_test".format(version)
        tests.append(test_name)
        cxx_no_flag_test(
            name = test_name,
            target_under_test = ":" + target_under_test,
            version = version,
        )

        test_name = "cxx{}_forced_17_flag_test".format(version)
        tests.append(test_name)
        cxx_forced_17_flag_test(
            name = test_name,
            target_under_test = ":" + target_under_test,
        )

        test_name = "cxx{}_forced_20_flag_test".format(version)
        tests.append(test_name)
        cxx_forced_20_flag_test(
            name = test_name,
            target_under_test = ":" + target_under_test,
        )

    return tests

def cxx_std_test_suite(name, **kwargs):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
        **kwargs: Additional keyword arguments.
    """
    tests = _cxx_std_test()

    native.test_suite(
        name = name,
        tests = tests,
        **kwargs
    )
