"""Tests for cc_binary with split functions."""

load("@rules_testing//lib:analysis_test.bzl", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching")
load("@rules_testing//lib:util.bzl", "util")
load("//cc:cc_binary.bzl", "cc_binary")
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test")

REQUIRED_TOOLCHAIN_FEATURES = [
    "fsafdo",
    "thin_lto",
    "supports_start_end_lib",
    "enable_fdo_split_functions",
    "fdo_optimize",
    "fdo_split_functions",
    "split_functions",
]

FSPLIT_MACHINE_FUNCTIONS_FLAG = "-fsplit-machine-functions"

def _test_implicit_split_functions(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/bin",
        srcs = ["bin.cc"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_implicit_split_functions_impl,
        targets = {
            "fdo": name + "/bin",
            "fsafdo": name + "/bin",
        },
        attrs = {
            "fdo": {
                "@config_settings": {
                    "//command_line_option:fdo_optimize": "/profile.zip",
                },
            },
            "fsafdo": {
                "@config_settings": {
                    "//command_line_option:fdo_optimize": "/profile.afdo",
                },
            },
        },
        config_settings = {
            "//command_line_option:compilation_mode": "opt",
        },
        with_features = REQUIRED_TOOLCHAIN_FEATURES,
        test_features = [
            "fdo_split_functions",
            "thin_lto",
        ],
        **kwargs
    )

def _test_implicit_split_functions_impl(env, targets):
    assert_fdo_lto_action = env.expect.that_target(targets.fdo).action_generating(
        "{package}/{test_name}/bin.lto/{bindir}/{package}/_objs/{name}/bin.o",
    )
    assert_fdo_lto_action.mnemonic().equals("CcLtoBackendCompile")
    assert_fdo_lto_action.argv().contains(FSPLIT_MACHINE_FUNCTIONS_FLAG)
    assert_fdo_lto_action.argv().contains("-DBUILD_MFS_ENABLED=1")

    assert_fsafdo_lto_action = env.expect.that_target(targets.fdo).action_generating(
        "{package}/{test_name}/bin.lto/{bindir}/{package}/_objs/{name}/bin.o",
    )
    assert_fsafdo_lto_action.mnemonic().equals("CcLtoBackendCompile")
    assert_fsafdo_lto_action.argv().contains(FSPLIT_MACHINE_FUNCTIONS_FLAG)
    assert_fsafdo_lto_action.argv().contains("-DBUILD_MFS_ENABLED=1")

def _test_no_implicit_split_functions(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/bin",
        srcs = ["bin.cc"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_no_implicit_split_functions_impl,
        targets = {
            "fdo": name + "/bin",
            "fsafdo": name + "/bin",
        },
        attrs = {
            "fdo": {
                "@config_settings": {
                    "//command_line_option:fdo_optimize": "/profile.zip",
                },
            },
            "fsafdo": {
                "@config_settings": {
                    "//command_line_option:fdo_optimize": "/profile.afdo",
                },
            },
        },
        config_settings = {
            "//command_line_option:compilation_mode": "opt",
        },
        with_features = REQUIRED_TOOLCHAIN_FEATURES,
        test_features = [
            "-fdo_split_functions",
            "thin_lto",
        ],
        **kwargs
    )

def _test_no_implicit_split_functions_impl(env, targets):
    assert_fdo_lto_action = env.expect.that_target(targets.fdo).action_generating(
        "{package}/{test_name}/bin.lto/{bindir}/{package}/_objs/{name}/bin.o",
    )
    assert_fdo_lto_action.mnemonic().equals("CcLtoBackendCompile")
    assert_fdo_lto_action.not_contains_arg(FSPLIT_MACHINE_FUNCTIONS_FLAG)

    assert_fsafdo_lto_action = env.expect.that_target(targets.fdo).action_generating(
        "{package}/{test_name}/bin.lto/{bindir}/{package}/_objs/{name}/bin.o",
    )
    assert_fsafdo_lto_action.mnemonic().equals("CcLtoBackendCompile")
    assert_fsafdo_lto_action.not_contains_arg(FSPLIT_MACHINE_FUNCTIONS_FLAG)

def _test_implicit_split_functions_disabled(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/bin",
        srcs = ["bin.cc"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_implicit_split_functions_disabled_impl,
        targets = {
            "fdo": name + "/bin",
            "fsafdo": name + "/bin",
        },
        attrs = {
            "fdo": {
                "@config_settings": {
                    "//command_line_option:fdo_optimize": "/profile.zip",
                },
            },
            "fsafdo": {
                "@config_settings": {
                    "//command_line_option:fdo_optimize": "/profile.afdo",
                },
            },
        },
        config_settings = {
            "//command_line_option:compilation_mode": "opt",
        },
        with_features = REQUIRED_TOOLCHAIN_FEATURES,
        test_features = [
            "-split_functions",
            "fdo_split_functions",
            "thin_lto",
        ],
        **kwargs
    )

def _test_implicit_split_functions_disabled_impl(env, targets):
    assert_fdo_lto_action = env.expect.that_target(targets.fdo).action_generating(
        "{package}/{test_name}/bin.lto/{bindir}/{package}/_objs/{name}/bin.o",
    )
    assert_fdo_lto_action.mnemonic().equals("CcLtoBackendCompile")
    assert_fdo_lto_action.not_contains_arg(FSPLIT_MACHINE_FUNCTIONS_FLAG)

    assert_fsafdo_lto_action = env.expect.that_target(targets.fdo).action_generating(
        "{package}/{test_name}/bin.lto/{bindir}/{package}/_objs/{name}/bin.o",
    )
    assert_fsafdo_lto_action.mnemonic().equals("CcLtoBackendCompile")
    assert_fsafdo_lto_action.not_contains_arg(FSPLIT_MACHINE_FUNCTIONS_FLAG)

def _test_propeller_optimize_disables_implicit_split_functions(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/bin",
        srcs = ["bin.cc"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_propeller_optimize_disables_implicit_split_functions_impl,
        targets = {
            "fdo": name + "/bin",
            "fsafdo": name + "/bin",
        },
        attrs = {
            "fdo": {
                "@config_settings": {
                    "//command_line_option:fdo_optimize": "/profile.zip",
                },
            },
            "fsafdo": {
                "@config_settings": {
                    "//command_line_option:fdo_optimize": "/profile.afdo",
                },
            },
        },
        config_settings = {
            "//command_line_option:compilation_mode": "opt",
            "//command_line_option:propeller_optimize_absolute_cc_profile": "/tmp/cc.txt",
        },
        with_features = REQUIRED_TOOLCHAIN_FEATURES,
        test_features = [
            "fdo_split_functions",
            "thin_lto",
        ],
        **kwargs
    )

def _test_propeller_optimize_disables_implicit_split_functions_impl(env, targets):
    assert_fdo_lto_action = env.expect.that_target(targets.fdo).action_generating(
        "{package}/{test_name}/bin.lto/{bindir}/{package}/_objs/{name}/bin.o",
    )
    assert_fdo_lto_action.mnemonic().equals("CcLtoBackendCompile")
    assert_fdo_lto_action.argv().contains_predicate(
        matching.str_matches("-fbasic-block-sections=list=*cc.txt"),
    )

    # Depending on the Bazel version, it may be enabled via the "type" flag or the "enabled" flag.
    assert_fdo_lto_action.argv().contains_predicate(
        matching.custom(
            "'-DBUILD_PROPELLER_ENABLED=1' or '-DBUILD_PROPELLER_TYPE=\"full\"'",
            lambda arg: arg in ["-DBUILD_PROPELLER_ENABLED=1", "-DBUILD_PROPELLER_TYPE=\"full\""],
        ),
    )
    assert_fdo_lto_action.not_contains_arg(FSPLIT_MACHINE_FUNCTIONS_FLAG)
    assert_fdo_lto_action.not_contains_arg("-DBUILD_PROPELLER_TYPE=\"split\"")

    assert_fsafdo_lto_action = env.expect.that_target(targets.fdo).action_generating(
        "{package}/{test_name}/bin.lto/{bindir}/{package}/_objs/{name}/bin.o",
    )
    assert_fsafdo_lto_action.mnemonic().equals("CcLtoBackendCompile")
    assert_fsafdo_lto_action.argv().contains_predicate(
        matching.str_matches("-fbasic-block-sections=list=*cc.txt"),
    )
    assert_fsafdo_lto_action.argv().contains_predicate(
        matching.custom(
            "'-DBUILD_PROPELLER_ENABLED=1' or '-DBUILD_PROPELLER_TYPE=\"full\"'",
            lambda arg: arg in ["-DBUILD_PROPELLER_ENABLED=1", "-DBUILD_PROPELLER_TYPE=\"full\""],
        ),
    )
    assert_fsafdo_lto_action.not_contains_arg(FSPLIT_MACHINE_FUNCTIONS_FLAG)
    assert_fsafdo_lto_action.not_contains_arg("-DBUILD_PROPELLER_TYPE=\"split\"")

def _test_propeller_optimize_with_explicit_split_functions(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/bin",
        srcs = ["bin.cc"],
    )

    cc_analysis_test(
        name = name,
        impl = _test_propeller_optimize_with_explicit_split_functions_impl,
        target = name + "/bin",
        config_settings = {
            "//command_line_option:compilation_mode": "opt",
            "//command_line_option:fdo_optimize": "/profile.zip",
            "//command_line_option:propeller_optimize_absolute_cc_profile": "/tmp/cc.txt",
        },
        with_features = REQUIRED_TOOLCHAIN_FEATURES,
        test_features = [
            "split_functions",
            "fdo_split_functions",
            "thin_lto",
        ],
        **kwargs
    )

def _test_propeller_optimize_with_explicit_split_functions_impl(env, target):
    assert_fdo_lto_action = env.expect.that_target(target).action_generating(
        "{package}/{test_name}/bin.lto/{bindir}/{package}/_objs/{name}/bin.o",
    )
    assert_fdo_lto_action.mnemonic().equals("CcLtoBackendCompile")
    assert_fdo_lto_action.argv().contains_predicate(
        matching.str_matches("-fbasic-block-sections=list=*cc.txt"),
    )
    assert_fdo_lto_action.argv().contains_predicate(
        matching.custom(
            "'-DBUILD_PROPELLER_ENABLED=1' or '-DBUILD_PROPELLER_TYPE=\"full\"'",
            lambda arg: arg in ["-DBUILD_PROPELLER_ENABLED=1", "-DBUILD_PROPELLER_TYPE=\"full\""],
        ),
    )
    assert_fdo_lto_action.argv().contains_at_least([
        "-DBUILD_MFS_ENABLED=1",
        FSPLIT_MACHINE_FUNCTIONS_FLAG,
    ])

def cc_binary_split_functions_tests(name):
    test_suite(
        name = name,
        tests = [
            _test_implicit_split_functions,
            _test_no_implicit_split_functions,
            _test_implicit_split_functions_disabled,
            _test_propeller_optimize_disables_implicit_split_functions,
            _test_propeller_optimize_with_explicit_split_functions,
        ],
    )
