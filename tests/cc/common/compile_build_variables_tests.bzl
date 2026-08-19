"""Tests for compile build variables."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@rules_testing//lib:analysis_test.bzl", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching", "subjects")
load("@rules_testing//lib:util.bzl", "TestingAspectInfo", "util")
load("//cc:action_names.bzl", "ACTION_NAMES")
load("//cc:cc_binary.bzl", _actual_cc_binary = "cc_binary")
load("//cc:find_cc_toolchain.bzl", "CC_TOOLCHAIN_ATTRS", "find_cpp_toolchain", "use_cc_toolchain")
load("//cc/common:cc_common.bzl", "cc_common")
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test")

_CompileVariablesInfo = provider(
    doc = "Arguments expanded from cc_common.create_compile_variables.",
    fields = ["arguments"],
)

def _compile_variables_test_rule_impl(ctx):
    cc_toolchain = find_cpp_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ["debug_variables"],
    )
    variables = cc_common.create_compile_variables(
        cc_toolchain = cc_toolchain,
        feature_configuration = feature_configuration,
        source_file = "test.cc",
        output_file = "test.o",
        variables_extension = ctx.attr.variables_extension,
    )
    return [_CompileVariablesInfo(arguments = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = ACTION_NAMES.cpp_compile,
        variables = variables,
    ))]

_compile_variables_test_rule = rule(
    implementation = _compile_variables_test_rule_impl,
    attrs = CC_TOOLCHAIN_ATTRS | {"variables_extension": attr.string_dict()},
    fragments = ["cpp"],
    toolchains = use_cc_toolchain(),
)

# Wrap cc_binary to mock out common dependencies.
def cc_binary(name, **kwargs):
    if "malloc" not in kwargs:
        kwargs["malloc"] = "//tests/cc/testutil/toolchains:mock_malloc"
    _actual_cc_binary(
        name = name,
        **kwargs
    )

def _compile_action(env, target, src_base_name):
    compile_action = env.expect.that_target(target).action_generating(
        "{package}/_objs/{name}/" + src_base_name + ".o",
    )
    compile_action.mnemonic().equals("CppCompile")
    return compile_action

def _variable(action, name):
    values = _variable_list(action, name)
    values.has_size(1)
    return values.offset(0, subjects.str)

def _variable_list(action, name):
    prefix = "--debug-var:{}=".format(name)
    return action.argv().transform(
        desc = "values of variable " + name,
        filter = lambda arg: arg.startswith(prefix),
        map_each = lambda arg: arg[len(prefix):],
    )

def _test_presence_of_basic_variables(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/bin",
        srcs = ["bin.cc"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_presence_of_basic_variables_impl,
        target = name + "/bin",
        **kwargs
    )

def _test_presence_of_basic_variables_impl(env, target):
    # make sure compile action's inputs match SOURCE_FILE
    _compile_action(env, target, "bin").inputs().contains("{package}/bin.cc")
    _variable_list(_compile_action(env, target, "bin"), "source_file").contains_exactly(["{package}/bin.cc"])

    # make sure compile action's output matches OUTPUT_FILE
    output_name_end = "{package}/_objs/{name}/bin.o".format(
        package = target.label.package,
        name = target.label.name,
    )
    _variable_list(_compile_action(env, target, "bin"), "output_file").contains_exactly_predicates(
        [matching.str_endswith(output_name_end)],
    )

def _test_presence_of_configuration_compile_flags(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/bin",
        srcs = ["bin.cc"],
        copts = ["-bar"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_presence_of_configuration_compile_flags_impl,
        target = name + "/bin",
        config_settings = {
            "//command_line_option:copt": ["-foo"],
        },
        **kwargs
    )

def _test_presence_of_configuration_compile_flags_impl(env, target):
    compile_action = _compile_action(env, target, "bin")
    _variable_list(compile_action, "user_compile_flags").contains_at_least(["-foo", "-bar"]).in_order()

def _test_presence_of_conly_flags(name, **kwargs):
    target_label = "//tests/cc/common:" + name + "/bin"
    util.helper_target(
        cc_binary,
        name = name + "/bin",
        srcs = [name + "/bin.c"],
        copts = ["-bar"],
        conlyopts = ["-baz"],
        cxxopts = ["-not-passed"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_presence_of_conly_flags_impl,
        target = name + "/bin",
        config_settings = {
            "//command_line_option:conlyopt": ["-foo"],
            "//command_line_option:cxxopt": ["-not-passed"],
            "//command_line_option:per_file_copt": [target_label + "@-per-file"],
        },
        **kwargs
    )

def _test_presence_of_conly_flags_impl(env, target):
    compile_action = _compile_action(env, target, "bin")
    user_compile_flags = _variable_list(compile_action, "user_compile_flags")
    user_compile_flags.contains_at_least(["-foo", "-bar", "-baz", "-per-file"]).in_order()
    user_compile_flags.not_contains("-not-passed")

def _test_cxx_flags_order(name, **kwargs):
    target_label = "//tests/cc/common:" + name + "/bin"
    util.helper_target(
        cc_binary,
        name = name + "/bin",
        srcs = [name + "/bin.cc"],
        copts = ["-bar"],
        cxxopts = ["-baz"],
        conlyopts = ["-not-passed"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_cxx_flags_order_impl,
        target = name + "/bin",
        config_settings = {
            "//command_line_option:cxxopt": ["-foo"],
            "//command_line_option:conlyopt": ["-not-passed"],
            "//command_line_option:per_file_copt": [target_label + "@-per-file"],
        },
        **kwargs
    )

def _test_cxx_flags_order_impl(env, target):
    compile_action = _compile_action(env, target, "bin")
    user_compile_flags = _variable_list(compile_action, "user_compile_flags")
    user_compile_flags.contains_at_least(["-foo", "-bar", "-baz", "-per-file"]).in_order()
    user_compile_flags.not_contains("-not-passed")

def _test_per_file_copts_are_in_user_compile_flags(name, **kwargs):
    target_label = "//tests/cc/common:" + name + "/bin"
    util.helper_target(
        cc_binary,
        name = name + "/bin",
        srcs = [name + "/bin.cc"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_per_file_copts_are_in_user_compile_flags_impl,
        target = name + "/bin",
        config_settings = {
            "//command_line_option:per_file_copt": [
                target_label + "@-foo",
                "//tests/cc/common:bar\\.cc@-bar",
            ],
            "//command_line_option:host_per_file_copt": [
                target_label + "@-baz",
            ],
        },
        **kwargs
    )

def _test_per_file_copts_are_in_user_compile_flags_impl(env, target):
    compile_action = _compile_action(env, target, "bin")
    user_compile_flags = _variable_list(compile_action, "user_compile_flags")
    user_compile_flags.contains("-foo")
    user_compile_flags.not_contains("-bar")
    user_compile_flags.not_contains("-baz")

def _test_host_per_file_copts_are_in_user_compile_flags(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/bin",
        srcs = [name + "/bin.cc"],
    )
    util.helper_target(
        util.force_exec_config,
        name = name + "/exec_wrapper",
        tools = [name + "/bin"],
    )
    target_label = "//tests/cc/common:" + name + "/bin"
    cc_analysis_test(
        name = name,
        impl = _test_host_per_file_copts_are_in_user_compile_flags_impl,
        target = name + "/exec_wrapper",
        config_settings = {
            "//command_line_option:host_per_file_copt": [
                "//tests/cc/common:.*bin\\.cc@-foo",
                "//tests/cc/common:bar\\.cc@-bar",
            ],
            "//command_line_option:per_file_copt": [
                target_label + "@-baz",
            ],
        },
        **kwargs
    )

def _test_host_per_file_copts_are_in_user_compile_flags_impl(env, target):
    bin_target = target[TestingAspectInfo].attrs.tools[0]
    compile_action = _compile_action(env, bin_target, "bin")
    user_compile_flags = _variable_list(compile_action, "user_compile_flags")
    user_compile_flags.contains("-foo")
    user_compile_flags.not_contains("-bar")
    user_compile_flags.not_contains("-baz")

def _test_presence_of_sysroot_build_variable(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/bin",
        srcs = ["bin.cc"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_presence_of_sysroot_build_variable_impl,
        target = name + "/bin",
        **kwargs
    )

def _test_presence_of_sysroot_build_variable_impl(env, target):
    compile_action = _compile_action(env, target, "bin")
    _variable(compile_action, "sysroot").equals("/usr/grte/v1")

def _test_compile_variables_extension_overrides_toolchain_variable(name, **kwargs):
    util.helper_target(
        _compile_variables_test_rule,
        name = name + "/variables",
        variables_extension = {"sysroot": "/overridden/sysroot"},
    )
    cc_analysis_test(
        name = name,
        impl = _test_compile_variables_extension_overrides_toolchain_variable_impl,
        target = name + "/variables",
        **kwargs
    )

def _test_compile_variables_extension_overrides_toolchain_variable_impl(env, target):
    env.expect.that_collection(target[_CompileVariablesInfo].arguments).contains(
        "--debug-var:sysroot=/overridden/sysroot",
    )

def _test_compile_variables_extension_rejects_duplicate_variables(name, **kwargs):
    util.helper_target(
        _compile_variables_test_rule,
        name = name + "/variables",
        variables_extension = {
            "user_compile_flags": "duplicate flags",
            "output_file": "duplicate output",
            "source_file": "duplicate source",
        },
    )
    cc_analysis_test(
        name = name,
        impl = _test_compile_variables_extension_rejects_duplicate_variables_impl,
        target = name + "/variables",
        expect_failure = True,
        **kwargs
    )

def _test_compile_variables_extension_rejects_duplicate_variables_impl(env, target):
    expected_error = "Cannot overwrite existing variables: [output_file, source_file, user_compile_flags]"
    env.expect.that_target(target).failures().contains_predicate(
        matching.custom(
            "contains '{}'".format(expected_error),
            lambda actual: expected_error in actual,
        ),
    )

def _test_target_sysroot_without_platforms(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/bin",
        srcs = ["bin.cc"],
    )
    util.helper_target(
        native.filegroup,
        name = name + "/target_libc",
    )
    cc_analysis_test(
        name = name,
        impl = _test_target_sysroot_without_platforms_impl,
        target = name + "/bin",
        config_settings = {
            "//command_line_option:grte_top": Label("//tests/cc/common:" + name + "/target_libc"),
            "//command_line_option:host_grte_top": Label("//tests/cc/testutil/toolchains:everything"),
        },
        **kwargs
    )

def _test_target_sysroot_without_platforms_impl(env, target):
    compile_action = _compile_action(env, target, "bin")
    _variable(compile_action, "sysroot").equals(target.label.package)

def _test_target_sysroot_with_platforms(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/bin",
        srcs = ["bin.cc"],
    )
    util.helper_target(
        native.filegroup,
        name = name + "/target_libc",
    )
    cc_analysis_test(
        name = name,
        impl = _test_target_sysroot_with_platforms_impl,
        target = name + "/bin",
        config_settings = {
            "//command_line_option:grte_top": Label("//tests/cc/common:" + name + "/target_libc"),
            "//command_line_option:host_grte_top": Label("//tests/cc/testutil/toolchains:everything"),
            "//command_line_option:platforms": [Label("//tests/cc/testutil/toolchains:linux_x86_64")],
        },
        **kwargs
    )

def _test_target_sysroot_with_platforms_impl(env, target):
    compile_action = _compile_action(env, target, "bin")
    _variable(compile_action, "sysroot").equals(target.label.package)

def _test_presence_of_is_using_fission_variable(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/bin",
        srcs = ["bin.cc"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_presence_of_is_using_fission_variable_impl,
        target = name + "/bin",
        test_features = ["per_object_debug_info"],
        config_settings = {
            "//command_line_option:fission": ["yes"],
        },
        **kwargs
    )

def _test_presence_of_is_using_fission_variable_impl(env, target):
    compile_action = _compile_action(env, target, "bin")
    _variable_list(compile_action, "is_using_fission").has_size(1)

def _test_presence_of_is_using_fission_and_per_debug_object_file_variables_with_thinlto(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/bin",
        srcs = ["bin.cc"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_presence_of_is_using_fission_and_per_debug_object_file_variables_with_thinlto_impl,
        target = name + "/bin",
        test_features = [
            "fission_flags_for_lto_backend",
            "per_object_debug_info",
            "supports_start_end_lib",
            "thin_lto",
            "supports_pic",
        ],
        config_settings = {
            "//command_line_option:fission": ["yes"],
            "//command_line_option:features": ["thin_lto"],
        },
        **kwargs
    )

def _test_presence_of_is_using_fission_and_per_debug_object_file_variables_with_thinlto_impl(env, target):
    bitcode_action = env.expect.that_target(target).action_named("CppCompile")
    backend_actions = [a for a in target[TestingAspectInfo].actions if a.mnemonic == "CcLtoBackendCompile"]
    env.expect.that_int(len(backend_actions)).is_greater_than(0)
    backend_action = env.expect.that_action(backend_actions[0])

    # We don't pass per_object_debug_info_file to bitcode compiles
    _variable_list(bitcode_action, "is_using_fission").has_size(1)
    _variable_list(bitcode_action, "per_object_debug_info_file").is_empty()

    # We do pass per_object_debug_info_file and is_using_fission to backend compiles
    _variable_list(backend_action, "is_using_fission").has_size(1)
    _variable_list(backend_action, "per_object_debug_info_file").has_size(1)

def _test_presence_of_per_object_debug_file_build_variable(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/bin",
        srcs = ["bin.cc"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_presence_of_per_object_debug_file_build_variable_impl,
        target = name + "/bin",
        test_features = ["per_object_debug_info"],
        config_settings = {
            "//command_line_option:fission": ["yes"],
        },
        **kwargs
    )

def _test_presence_of_per_object_debug_file_build_variable_impl(env, target):
    compile_action = _compile_action(env, target, "bin")
    _variable_list(compile_action, "per_object_debug_info_file").has_size(1)

def _test_presence_of_min_os_version_build_variable(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/bin",
        srcs = ["bin.cc"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_presence_of_min_os_version_build_variable_impl,
        target = name + "/bin",
        test_features = ["min_os_version_flag"],
        config_settings = {
            "//command_line_option:minimum_os_version": "6",
        },
        **kwargs
    )

def _test_presence_of_min_os_version_build_variable_impl(env, target):
    compile_action = _compile_action(env, target, "bin")
    _variable(compile_action, "minimum_os_version").equals("6")

def compile_build_variables_tests(name):
    """Creates the test targets for compile build variables tests.

    Args:
        name: The name of the test suite.
    """
    tests = [
        _test_presence_of_basic_variables,
        _test_presence_of_configuration_compile_flags,
        _test_presence_of_conly_flags,
        _test_cxx_flags_order,
        _test_per_file_copts_are_in_user_compile_flags,
        _test_host_per_file_copts_are_in_user_compile_flags,
        _test_presence_of_sysroot_build_variable,
        _test_target_sysroot_without_platforms,
        _test_target_sysroot_with_platforms,
        _test_presence_of_is_using_fission_variable,
        _test_presence_of_is_using_fission_and_per_debug_object_file_variables_with_thinlto,
        _test_presence_of_per_object_debug_file_build_variable,
        _test_presence_of_min_os_version_build_variable,
    ]
    if bazel_features.cc.cc_common_is_in_rules_cc:
        tests.extend([
            _test_compile_variables_extension_overrides_toolchain_variable,
            _test_compile_variables_extension_rejects_duplicate_variables,
        ])
    test_suite(
        name = name,
        tests = tests,
    )
