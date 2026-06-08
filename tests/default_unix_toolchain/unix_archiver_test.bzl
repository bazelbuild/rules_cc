"""Tests for archiver selection in the default Unix toolchain."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test")

_USE_LIBTOOL_ON_MACOS = str(Label("//cc/toolchains/args/archiver_flags:use_libtool_on_macos"))
_MACOS_PLATFORM = str(Label("//tests/default_unix_toolchain:macos"))
_MACOS_TOOLCHAIN = str(Label("//tests/default_unix_toolchain:macos_cc_toolchain_registration"))

def _archive_action(env, target):
    archive_actions = [action for action in target.actions if action.mnemonic == "CppArchive"]
    env.expect.that_collection(archive_actions).has_size(1)
    return archive_actions[0]

def _uses_libtool_test_impl(env, target):
    argv = _archive_action(env, target).argv
    env.expect.that_str(argv[0]).equals("/usr/bin/libtool")
    env.expect.that_collection(argv).contains_at_least([
        "-D",
        "-no_warning_for_no_symbols",
        "-static",
        "-o",
    ])

def _uses_ar_test_impl(env, target):
    argv = _archive_action(env, target).argv
    env.expect.that_str(argv[0]).equals("/usr/bin/ar")
    env.expect.that_collection(argv).contains("rcs")
    env.expect.that_collection(argv).not_contains("-no_warning_for_no_symbols")
    env.expect.that_collection(argv).not_contains("-static")
    env.expect.that_collection(argv).not_contains("-o")

def unix_archiver_tests(name, target):
    analysis_test(
        name = name + "_uses_libtool",
        target = target,
        impl = _uses_libtool_test_impl,
        config_settings = {
            _USE_LIBTOOL_ON_MACOS: True,
            "//command_line_option:extra_toolchains": [_MACOS_TOOLCHAIN],
            "//command_line_option:platforms": [_MACOS_PLATFORM],
        },
    )
    analysis_test(
        name = name + "_uses_ar",
        target = target,
        impl = _uses_ar_test_impl,
        config_settings = {
            _USE_LIBTOOL_ON_MACOS: False,
            "//command_line_option:extra_toolchains": [_MACOS_TOOLCHAIN],
            "//command_line_option:platforms": [_MACOS_PLATFORM],
        },
    )

    native.test_suite(
        name = name,
        tests = [
            name + "_uses_ar",
            name + "_uses_libtool",
        ],
    )
