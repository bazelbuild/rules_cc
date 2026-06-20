"""Tests that cc_shared_library produces interface libraries and dependents use them."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@rules_testing//lib:analysis_test.bzl", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching")
load("@rules_testing//lib:util.bzl", "util")
load("//cc:cc_binary.bzl", _actual_cc_binary = "cc_binary")
load("//cc:cc_library.bzl", "cc_library")
load("//cc:cc_shared_library.bzl", "cc_shared_library")
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test")
load("//tests/cc/testutil/toolchains:features.bzl", "FEATURE_NAMES")

def cc_binary(name, **kwargs):
    if "malloc" not in kwargs:
        kwargs["malloc"] = "//tests/cc/testutil/toolchains:mock_malloc"
    _actual_cc_binary(
        name = name,
        **kwargs
    )

def _test_shared_library_produces_ifso(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/base_lib",
        srcs = ["hello.cc"],
    )
    util.helper_target(
        cc_shared_library,
        name = name + "/inner_so",
        deps = [name + "/base_lib"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_shared_library_produces_ifso_impl,
        target = name + "/inner_so",
        test_features = [
            FEATURE_NAMES.supports_interface_shared_libraries,
        ],
        config_settings = {
            "//command_line_option:interface_shared_objects": True,
        },
        **kwargs
    )

def _test_shared_library_produces_ifso_impl(env, target):
    output_group = target[OutputGroupInfo].interface_library.to_list()
    env.expect.that_collection(
        [f.short_path for f in output_group],
    ).contains_predicate(matching.str_endswith(".ifso"))

def _shared_lib_targets(name):
    """Creates shared targets for the binary and transitive ifso tests."""
    util.helper_target(
        cc_library,
        name = name + "/base_lib",
        srcs = ["hello.cc"],
    )
    util.helper_target(
        cc_shared_library,
        name = name + "/inner_so",
        deps = [name + "/base_lib"],
    )
    util.helper_target(
        cc_library,
        name = name + "/middle_lib",
        srcs = ["hello.cc"],
    )
    util.helper_target(
        cc_shared_library,
        name = name + "/outer_so",
        deps = [name + "/middle_lib"],
        dynamic_deps = [name + "/inner_so"],
    )
    util.helper_target(
        cc_binary,
        name = name + "/binary",
        srcs = ["hello.cc"],
        dynamic_deps = [name + "/outer_so"],
    )

def _test_binary_links_against_ifso(name, **kwargs):
    _shared_lib_targets(name)
    cc_analysis_test(
        name = name,
        impl = _test_binary_links_against_ifso_impl,
        target = name + "/binary",
        test_features = [
            FEATURE_NAMES.supports_interface_shared_libraries,
        ],
        config_settings = {
            "//command_line_option:interface_shared_objects": True,
        },
        **kwargs
    )

def _test_binary_links_against_ifso_impl(env, target):
    executable = target[DefaultInfo].files_to_run.executable
    link_action = env.expect.that_target(target).action_generating(executable.short_path)

    link_inputs = [f.short_path for f in link_action.actual.inputs.to_list()]

    # The binary directly links against outer_so. It should use the .ifso
    # interface library, not the full .so.
    env.expect.that_collection(link_inputs).contains_predicate(
        matching.custom("ends with libouter_so.ifso", lambda x: x.endswith("libouter_so.ifso")),
    )
    env.expect.that_collection(link_inputs).contains_none_of([
        matching.custom("ends with libouter_so.so", lambda x: x.endswith("libouter_so.so")),
    ])

def _test_shared_lib_links_against_ifso(name, **kwargs):
    _shared_lib_targets(name)
    cc_analysis_test(
        name = name,
        impl = _test_shared_lib_links_against_ifso_impl,
        target = name + "/outer_so",
        test_features = [
            FEATURE_NAMES.supports_interface_shared_libraries,
        ],
        config_settings = {
            "//command_line_option:interface_shared_objects": True,
        },
        **kwargs
    )

def _test_shared_lib_links_against_ifso_impl(env, target):
    # Find the link action for outer_so by looking for the .so output.
    so_files = [f for f in target[DefaultInfo].files.to_list() if f.short_path.endswith(".so")]
    link_action = env.expect.that_target(target).action_generating(so_files[0].short_path)

    link_inputs = [f.short_path for f in link_action.actual.inputs.to_list()]

    # outer_so links against inner_so. It should use the .ifso.
    env.expect.that_collection(link_inputs).contains_predicate(
        matching.custom("contains libinner_so.ifso", lambda x: x.endswith("libinner_so.ifso")),
    )
    env.expect.that_collection(link_inputs).contains_none_of([
        matching.custom("contains with libinner_so.so", lambda x: x.endswith("libinner_so.so")),
    ])

def _test_link_command_uses_link_dynamic_library_sh(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/lib",
        srcs = ["hello.cc"],
    )
    util.helper_target(
        cc_shared_library,
        name = name + "/mylib",
        deps = [name + "/lib"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_link_command_uses_link_dynamic_library_sh_impl,
        target = name + "/mylib",
        test_features = [
            FEATURE_NAMES.supports_interface_shared_libraries,
        ],
        config_settings = {
            "//command_line_option:interface_shared_objects": True,
        },
        **kwargs
    )

def _test_link_command_uses_link_dynamic_library_sh_impl(env, target):
    so_files = [f for f in target[DefaultInfo].files.to_list() if f.short_path.endswith(".so")]
    link_action = env.expect.that_target(target).action_generating(so_files[0].short_path)
    argv = link_action.actual.argv

    # When supports_interface_shared_libraries is enabled
    #   0. Use link_dynamic_library.sh
    #   1. generate_interface_library (yes/no)
    #   2. interface_library_builder_path
    #   3. interface_library_input_path (the .so)
    #   4. interface_library_output_path (the .ifso)
    #   5. linker_command (path to the actual linker)
    #   ... the normal linker flags.
    env.expect.that_str(argv[0]).contains("link_dynamic_library.sh")
    env.expect.that_str(argv[1]).equals("yes")
    env.expect.that_str(argv[2]).contains("build_interface_so")
    env.expect.that_str(argv[3]).contains("libmylib.so")
    env.expect.that_str(argv[4]).contains("libmylib.ifso")

def _test_link_command_with_configured_linker_path(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/lib",
        srcs = ["hello.cc"],
    )
    util.helper_target(
        cc_shared_library,
        name = name + "/mylib",
        deps = [name + "/lib"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_link_command_with_configured_linker_path_impl,
        target = name + "/mylib",
        test_features = [
            FEATURE_NAMES.supports_interface_shared_libraries,
            FEATURE_NAMES.has_configured_linker_path,
        ],
        config_settings = {
            "//command_line_option:interface_shared_objects": True,
        },
        **kwargs
    )

def _test_link_command_with_configured_linker_path_impl(env, target):
    so_files = [f for f in target[DefaultInfo].files.to_list() if f.short_path.endswith(".so")]
    link_action = env.expect.that_target(target).action_generating(so_files[0].short_path)
    argv = link_action.actual.argv

    # With has_configured_linker_path, the action tool is the normal linker
    # (not link_dynamic_library.sh). The interface library variables are still
    # passed as flags via the build_interface_libraries feature.
    env.expect.that_collection(argv).contains_none_of([
        matching.str_endswith("link_dynamic_library.sh"),
    ])

    env.expect.that_collection(argv).contains("yes")
    env.expect.that_collection(argv).contains_predicate(
        matching.custom("contains build_interface_so", lambda x: "build_interface_so" in x),
    )

def cc_shared_library_interface_tests(name):
    tests = []
    if bazel_features.cc.cc_common_is_in_rules_cc:
        tests = [
            _test_shared_library_produces_ifso,
            _test_binary_links_against_ifso,
            _test_shared_lib_links_against_ifso,
            _test_link_command_uses_link_dynamic_library_sh,
            _test_link_command_with_configured_linker_path,
        ]
    test_suite(
        name = name,
        tests = tests,
    )
