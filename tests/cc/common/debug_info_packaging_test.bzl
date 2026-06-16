"""Tests for debug info packaging (Fission)."""

load("@rules_testing//lib:analysis_test.bzl", "test_suite")
load("@rules_testing//lib:truth.bzl", "subjects")
load("@rules_testing//lib:util.bzl", "util")
load("//cc:cc_binary.bzl", "cc_binary")
load("//cc:cc_library.bzl", "cc_library")
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test")
load("//tests/cc/testutil/toolchains:features.bzl", "FEATURE_NAMES")

def _create_fission_binary(name):
    util.empty_file(name + "_fission.cc")
    util.helper_target(
        cc_binary,
        name = name + "_fission",
        srcs = [name + "_fission.cc"],
    )

def _test_dwp_output_names(name):
    """Verifies the names of expected implicit .dwp outputs for supporting cc_* rules."""
    _create_fission_binary(name)
    cc_analysis_test(
        name = name,
        impl = _test_dwp_output_names_impl,
        target = name + "_fission",
        with_features = [FEATURE_NAMES.supports_pic, FEATURE_NAMES.per_object_debug_info],
        config_settings = {
            "//command_line_option:fission": "yes",
            "//command_line_option:force_pic": True,
        },
    )

def _test_dwp_output_names_impl(env, target):
    executable = target[DefaultInfo].files_to_run.executable
    dwp_path = executable.short_path + ".dwp"
    dwp_action = env.expect.that_target(target).action_generating(dwp_path)
    dwp_action.mnemonic().equals("CcGenerateDwp")

def _test_dwp_builds_require_fission_mode_disabled(name):
    """Tests that .dwp files can be built in both fission and non-fission configurations."""
    _create_fission_binary(name)
    cc_analysis_test(
        name = name,
        impl = _test_dwp_builds_require_fission_mode_disabled_impl,
        target = name + "_fission",
        with_features = [FEATURE_NAMES.supports_pic, FEATURE_NAMES.per_object_debug_info],
        config_settings = {
            "//command_line_option:fission": "no",
        },
    )

def _test_dwp_builds_require_fission_mode_disabled_impl(env, target):
    # Fission disabled (output is a non-meaningful empty file):
    executable = target[DefaultInfo].files_to_run.executable
    dwp_path = executable.short_path + ".dwp"
    action = env.expect.that_target(target).action_generating(dwp_path)
    action.mnemonic().equals("FileWrite")
    action.content().equals("")

def _test_dwp_builds_require_fission_mode_enabled(name):
    """Tests that .dwp files can be built in both fission and non-fission configurations."""
    _create_fission_binary(name)
    cc_analysis_test(
        name = name,
        impl = _test_dwp_builds_require_fission_mode_enabled_impl,
        target = name + "_fission",
        with_features = [FEATURE_NAMES.supports_pic, FEATURE_NAMES.per_object_debug_info],
        config_settings = {
            "//command_line_option:fission": "yes",
            "//command_line_option:force_pic": True,
        },
    )

def _test_dwp_builds_require_fission_mode_enabled_impl(env, target):
    # Fission enabled:
    executable = target[DefaultInfo].files_to_run.executable
    dwp_path = executable.short_path + ".dwp"
    action = env.expect.that_target(target).action_generating(dwp_path)
    action.mnemonic().equals("CcGenerateDwp")

def _test_dwp_action_structure(name):
    """Tests the structure (i.e. inputs, outputs, command line) of the action that generates a target's .dwp."""
    _create_fission_binary(name)
    cc_analysis_test(
        name = name,
        impl = _test_dwp_action_structure_impl,
        target = name + "_fission",
        with_features = [FEATURE_NAMES.supports_pic, FEATURE_NAMES.per_object_debug_info],
        config_settings = {
            "//command_line_option:fission": "yes",
            "//command_line_option:force_pic": True,
        },
    )

def _test_dwp_action_structure_impl(env, target):
    executable = target[DefaultInfo].files_to_run.executable
    dwp_path = executable.short_path + ".dwp"
    action = env.expect.that_target(target).action_generating(dwp_path)

    action.mnemonic().equals("CcGenerateDwp")

    argv = action.argv()

    # The first argument should be the command being executed.
    argv.offset(0, subjects.str).equals("/usr/bin/mock-dwp")

    # The final two arguments should be "-o dwpOutputFile".
    argv.offset(-2, subjects.str).equals("-o")
    argv.offset(-1, subjects.str).ends_with("/" + dwp_path)

    # The remaining arguments should be the set of .dwo inputs.
    dwo_files = _get_dwo_files_subject(env, target, dwp_path)
    expected_dwo = "{package}/_objs/{target}/{target}.pic.dwo".format(
        package = target.label.package,
        target = target.label.name,
    )
    dwo_files.contains_exactly([expected_dwo])

def _create_dwo_input_set_tree(name, linkstatic):
    util.empty_file(name + "_lib1.cc")
    util.empty_file(name + "_lib2.cc")
    util.empty_file(name + "_lib_pregen.o")
    util.empty_file(name + "_test_malloc.cc")
    util.empty_file(name + "_main.cc")
    util.empty_file(name + "_bin_pregen.o")

    util.helper_target(
        cc_library,
        name = name + "_lib",
        srcs = [
            name + "_lib1.cc",
            name + "_lib2.cc",
            name + "_lib_pregen.o",
        ],
    )
    util.helper_target(
        cc_library,
        name = name + "_test_malloc",
        srcs = [name + "_test_malloc.cc"],
    )
    util.helper_target(
        cc_library,
        name = name + "_empty_lib",
    )
    util.helper_target(
        cc_binary,
        name = name + "_binary",
        srcs = [
            name + "_main.cc",
            name + "_bin_pregen.o",
        ],
        deps = [name + "_lib"],
        malloc = name + "_test_malloc",
        link_extra_lib = name + "_empty_lib",  # copybara:strip
        linkstatic = linkstatic,
    )

def _get_dwo_files_subject(env, target, dwp_path):
    action = env.expect.that_target(target).action_generating(dwp_path)
    dwo_files = []
    package_prefix = target.label.package + "/"
    for f in action.actual.inputs.to_list():
        if f.basename.endswith(".dwo") and f.short_path.startswith(package_prefix):
            dwo_files.append(f.short_path)
        elif f.basename.endswith(".dwp") and f.short_path != dwp_path:
            sub_action = env.expect.that_target(target).action_generating(f.short_path)
            for sf in sub_action.actual.inputs.to_list():
                if sf.basename.endswith(".dwo") and sf.short_path.startswith(package_prefix):
                    dwo_files.append(sf.short_path)
    return env.expect.that_collection(dwo_files)

def _test_dwo_input_set_pic_mode(name):
    """Tests that the set of input .dwo files is as expected.

    This set should consist of the corresponding .dwo for every generated .o file
    that is fed into a binary's link. Note that "generated .o" files are distinguished
    from "source .o" files: .o files checked directly into the depot are not compiled
    at build time and thus have no corresponding .dwo.

    This version of the test applies "pic-mode" linking (.pic.o files are linked in
    over their .o counterparts).

    Args:
        name: test target name
    """
    _create_dwo_input_set_tree(name, linkstatic = True)
    cc_analysis_test(
        name = name,
        impl = _test_dwo_input_set_pic_mode_impl,
        target = name + "_binary",
        with_features = [FEATURE_NAMES.supports_pic, FEATURE_NAMES.per_object_debug_info],
        config_settings = {
            "//command_line_option:fission": "yes",
            "//command_line_option:force_pic": True,
        },
    )

def _test_dwo_input_set_pic_mode_impl(env, target):
    executable = target[DefaultInfo].files_to_run.executable
    dwp_path = executable.short_path + ".dwp"
    dwo_files = _get_dwo_files_subject(env, target, dwp_path)

    pkg = target.label.package
    prefix = target.label.name.replace("_binary", "")
    lib_target = prefix + "_lib"
    malloc_target = prefix + "_test_malloc"
    bin_target = prefix + "_binary"

    expected = [
        "{pkg}/_objs/{lib}/{prefix}_lib1.pic.dwo".format(pkg = pkg, lib = lib_target, prefix = prefix),
        "{pkg}/_objs/{lib}/{prefix}_lib2.pic.dwo".format(pkg = pkg, lib = lib_target, prefix = prefix),
        "{pkg}/_objs/{malloc}/{prefix}_test_malloc.pic.dwo".format(pkg = pkg, malloc = malloc_target, prefix = prefix),
        "{pkg}/_objs/{bin}/{prefix}_main.pic.dwo".format(pkg = pkg, bin = bin_target, prefix = prefix),
    ]
    dwo_files.contains_exactly(expected)

def _test_dwo_input_set_dynamic_mode(name):
    """Tests the .dwo input set for a dynamically linked binary.

    As described above, the .dwo input set for a binary should roughly correspond to
    the .o files that are fed into the binary's link. For a dynamically linked
    binary, this excludes everything in dependent dynamic libraries.

    Args:
        name: test target name
    """
    _create_dwo_input_set_tree(name, linkstatic = False)
    cc_analysis_test(
        name = name,
        impl = _test_dwo_input_set_dynamic_mode_impl,
        target = name + "_binary",
        with_features = [FEATURE_NAMES.supports_pic, FEATURE_NAMES.per_object_debug_info],
        config_settings = {
            "//command_line_option:fission": "yes",
            "//command_line_option:force_pic": True,
        },
    )

def _test_dwo_input_set_dynamic_mode_impl(env, target):
    executable = target[DefaultInfo].files_to_run.executable
    dwp_path = executable.short_path + ".dwp"
    dwo_files = _get_dwo_files_subject(env, target, dwp_path)

    pkg = target.label.package
    prefix = target.label.name.replace("_binary", "")
    bin_target = prefix + "_binary"
    expected_main = "{pkg}/_objs/{bin}/{prefix}_main.pic.dwo".format(pkg = pkg, bin = bin_target, prefix = prefix)

    dwo_files.contains_exactly([expected_main])

def debug_info_packaging_tests(name):
    test_suite(
        name = name,
        tests = [
            _test_dwp_output_names,
            _test_dwp_builds_require_fission_mode_disabled,
            _test_dwp_builds_require_fission_mode_enabled,
            _test_dwp_action_structure,
            _test_dwo_input_set_pic_mode,
            _test_dwo_input_set_dynamic_mode,
        ],
    )
