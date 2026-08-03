"""Tests for fission flags on ThinLTO backend actions in the default Unix toolchain."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test")

_LINUX_PLATFORM = str(Label("//tests/default_unix_toolchain:linux"))
_LINUX_TOOLCHAIN = str(Label("//tests/default_unix_toolchain:linux_cc_toolchain_registration"))

def _lto_backend_action(env, target):
    backend_actions = [
        action
        for action in target.actions
        if action.mnemonic == "CcLtoBackendCompile"
    ]
    env.expect.that_collection(backend_actions).has_size(1)
    return backend_actions[0]

def _fission_on_lto_backend_test_impl(env, target):
    action = _lto_backend_action(env, target)

    # Fission is enabled, so a .dwo output is declared for the backend action.
    dwo_outputs = [
        file.path
        for file in action.outputs.to_list()
        if file.path.endswith(".dwo")
    ]
    env.expect.that_collection(dwo_outputs).has_size(1)

    # The backend action is the one that emits the object file, so it is the
    # action that has to be told to split the debug info out of it.
    env.expect.that_collection(action.argv).contains("-gsplit-dwarf")

def unix_fission_tests(name, target):
    analysis_test(
        name = name + "_lto_backend_fission_flags",
        target = target,
        impl = _fission_on_lto_backend_test_impl,
        config_settings = {
            "//command_line_option:extra_toolchains": [_LINUX_TOOLCHAIN],
            "//command_line_option:features": [
                "thin_lto",
                "per_object_debug_info",
            ],
            "//command_line_option:fission": ["yes"],
            "//command_line_option:platforms": [_LINUX_PLATFORM],
        },
    )

    native.test_suite(
        name = name,
        tests = [name + "_lto_backend_fission_flags"],
    )
