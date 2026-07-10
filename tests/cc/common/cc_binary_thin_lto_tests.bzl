"""Tests for cc_binary with ThinLTO."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@rules_testing//lib:analysis_test.bzl", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching", "subjects")
load("@rules_testing//lib:util.bzl", "TestingAspectInfo", "util")
load("//cc:cc_binary.bzl", _actual_cc_binary = "cc_binary")
load("//cc:cc_library.bzl", "cc_library")
load("//cc:cc_test.bzl", _actual_cc_test = "cc_test")
load("//tests/cc/testutil:cc_analysis_test.bzl", "cc_analysis_test")
load("//tests/cc/testutil:cc_binary_target_subject.bzl", "cc_binary_target_subject")

# Wrap cc_binary to mock out common dependencies.
def cc_binary(name, **kwargs):
    if "malloc" not in kwargs:
        kwargs["malloc"] = "//tests/cc/testutil/toolchains:mock_malloc"
    _actual_cc_binary(
        name = name,
        **kwargs
    )

# Wrap cc_test to mock out common dependencies.
def cc_test(name, **kwargs):
    if "malloc" not in kwargs:
        kwargs["malloc"] = "//tests/cc/testutil/toolchains:mock_malloc"
    _actual_cc_test(
        name = name,
        **kwargs
    )

def _test_thin_lto_action_graph(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/lib",
        srcs = ["bye.cc"],
        hdrs = ["bye.h"],
        linkstamp = "linkstamp.cc",
    )
    util.helper_target(
        cc_binary,
        name = name + "/bin",
        srcs = ["hello.cc"],
        deps = [":" + name + "/lib"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_thin_lto_action_graph_impl,
        target = name + "/bin",
        test_features = ["thin_lto", "supports_pic", "supports_start_end_lib"],
        **kwargs
    )

def _test_thin_lto_action_graph_impl(env, target):
    package = target.label.package
    name = target.label.name
    bindir = target[TestingAspectInfo].bin_path

    test_name = name.split("/")[0]
    lib_name = test_name + "/lib"

    binary_obj_path = "{package}/{name}.lto/{bindir}/{package}/_objs/{name}/hello.pic.o".format(
        package = package,
        name = name,
        bindir = bindir,
    )
    library_obj_path = "{package}/{name}.lto/{bindir}/{package}/_objs/{lib_name}/bye.pic.o".format(
        package = package,
        name = name,
        bindir = bindir,
        lib_name = lib_name,
    )
    params_path = "{package}/{name}-lto-final.params".format(
        package = package,
        name = name,
    )
    param_file_arg = "thinlto_param_file={bindir}/{params_path}".format(
        bindir = bindir,
        params_path = params_path,
    )

    binary_target = cc_binary_target_subject.from_target(env, target)
    link_action = binary_target.action_generating("{package}/{name}{binary_extension}")

    link_action.inputs().contains(binary_obj_path)
    link_action.inputs().contains(library_obj_path)
    link_action.inputs().contains(params_path)

    # Check linkstamp
    link_action.inputs().contains_predicate(matching.file_basename_contains("linkstamp"))

    # Check argv
    link_action.argv().contains_at_least([
        "{bindir}/{package}/{name}.lto.merged.o".format(bindir = bindir, package = package, name = name),
        param_file_arg,
    ]).in_order()

    # Check that all our _objs args (except linkstamp) are in LTO dir
    lto_dir = "{package}/{name}.lto".format(package = package, name = name)
    objs_args = link_action.argv().transform(
        desc = "object arguments",
        filter = lambda arg: "_objs" in arg and "linkstamp" not in arg and package in arg,
    )
    bad_args = objs_args.transform(
        desc = "object arguments not using LTO paths",
        filter = lambda arg: lto_dir not in arg,
    )
    bad_args.is_empty()

    # Backend action
    backend_action = env.expect.that_target(target).action_generating(binary_obj_path)
    backend_action.mnemonic().equals("CcLtoBackendCompile")
    backend_action.inputs().contains(binary_obj_path + ".thinlto.bc")
    backend_action.inputs().contains(binary_obj_path + ".imports")

    thinlto_index_arg = "thinlto_index={bindir}/{package}/{name}.lto/{bindir}/{package}/_objs/{name}/hello.pic.o".format(
        package = package,
        name = name,
        bindir = bindir,
    ) + ".thinlto.bc"
    thinlto_output_arg = "thinlto_output_object_file={bindir}/{package}/{name}.lto/{bindir}/{package}/_objs/{name}/hello.pic.o".format(
        package = package,
        name = name,
        bindir = bindir,
    )
    thinlto_input_arg = "thinlto_input_bitcode_file={bindir}/{package}/_objs/{name}/hello.pic.o".format(
        package = package,
        name = name,
        bindir = bindir,
    )
    backend_action.argv().contains_at_least([
        thinlto_index_arg,
        thinlto_output_arg,
        thinlto_input_arg,
    ])

    # Index action
    index_action = env.expect.that_target(target).action_generating(binary_obj_path + ".thinlto.bc")
    index_action.mnemonic().equals("CppLTOIndexing")

    # Linkstamp compile action should not be input to indexing
    linkstamp_compile_action = env.expect.that_target(target).action_named("CppLinkstampCompile")
    linkstamp_outputs = linkstamp_compile_action.actual.outputs.to_list()
    index_action.inputs().contains_none_of(linkstamp_outputs)

    index_action.argv().not_contains(
        param_file_arg,
    )

    index_outputs = env.expect.that_depset_of_files(index_action.actual.outputs)
    index_outputs.contains(binary_obj_path + ".imports")
    index_outputs.contains(binary_obj_path + ".thinlto.bc")
    index_outputs.contains(library_obj_path + ".imports")
    index_outputs.contains(library_obj_path + ".thinlto.bc")
    index_outputs.contains(params_path)

    binary_indexing_obj = "{package}/_objs/{name}/hello.pic.indexing.o".format(
        package = package,
        name = name,
    )
    library_indexing_obj = "{package}/_objs/{lib_name}/bye.pic.indexing.o".format(
        package = package,
        lib_name = lib_name,
    )
    index_action.inputs().contains(binary_indexing_obj)
    index_action.inputs().contains(library_indexing_obj)

    bitcode_action = env.expect.that_target(target).action_generating(binary_indexing_obj)
    bitcode_action.mnemonic().equals("CppCompile")
    bitcode_action.argv().contains(
        "lto_indexing_bitcode={bindir}/{binary_indexing_obj}".format(
            bindir = bindir,
            binary_indexing_obj = binary_indexing_obj,
        ),
    )

def _test_thin_lto_linkshared(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/lib",
        srcs = ["bye.cc"],
        hdrs = ["bye.h"],
    )
    util.helper_target(
        cc_binary,
        name = name + "/bin.so",
        srcs = ["hello.cc"],
        deps = [":" + name + "/lib"],
        linkshared = 1,
    )
    cc_analysis_test(
        name = name,
        impl = _test_thin_lto_linkshared_impl,
        target = name + "/bin.so",
        test_features = ["thin_lto", "supports_pic", "supports_start_end_lib", "user_compile_flags"],
        config_settings = {
            "//command_line_option:linkopt": ["alinkopt"],
        },
        **kwargs
    )

def _test_thin_lto_linkshared_impl(env, target):
    package = target.label.package
    name = target.label.name
    bindir = target[TestingAspectInfo].bin_path

    binary_obj_path = "{package}/{name}.lto/{bindir}/{package}/_objs/{name}/hello.pic.o".format(
        package = package,
        name = name,
        bindir = bindir,
    )

    backend_action = env.expect.that_target(target).action_generating(binary_obj_path)
    backend_action.mnemonic().equals("CcLtoBackendCompile")
    backend_action.argv().not_contains("alinkopt")

def _test_thin_lto_no_linkstatic(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/lib",
        srcs = ["bye.cc"],
        hdrs = ["bye.h"],
    )
    util.helper_target(
        cc_binary,
        name = name + "/bin",
        srcs = ["hello.cc"],
        deps = [":" + name + "/lib"],
        linkstatic = 0,
    )
    cc_analysis_test(
        name = name,
        impl = _test_thin_lto_no_linkstatic_impl,
        targets = {
            "bin": name + "/bin",
            "lib": name + "/lib",
        },
        test_features = [
            "thin_lto",
            "supports_pic",
            "supports_start_end_lib",
            "supports_dynamic_linker",
            "supports_interface_shared_libraries",
        ],
        **kwargs
    )

def _test_thin_lto_no_linkstatic_impl(env, targets):
    bin_target = targets.bin
    lib_target = targets.lib

    package = bin_target.label.package
    name = bin_target.label.name
    bindir = bin_target[TestingAspectInfo].bin_path

    test_name = name.split("/")[0]
    lib_target_name = test_name + "/lib"

    binary_target = cc_binary_target_subject.from_target(env, bin_target)
    link_action = binary_target.action_generating("{package}/{name}{binary_extension}")

    # TODO(b/526555277): Propose enhancement to rules_testing to add transform/to_collection to DepsetFileSubject.
    # Manually wrap inputs in CollectionSubject to use transform
    link_inputs_collection = subjects.collection(
        link_action.actual.inputs.to_list(),
        link_action.meta.derive("inputs()"),
    )
    solib_inputs = link_inputs_collection.transform(
        desc = "solib inputs",
        filter = lambda f: "_solib" in f.path and "linkstatic_Sliblib" in f.path,
    )
    solib_inputs.has_size(1)
    solib_file = solib_inputs.offset(0, subjects.file).actual

    lib_target_subject = env.expect.that_target(lib_target)
    solib_action = lib_target_subject.action_generating(solib_file.short_path)
    solib_action.mnemonic().equals("SolibSymlink")

    # The input to SolibSymlink is the library itself
    solib_action_inputs = solib_action.actual.inputs.to_list()
    lib_file = solib_action_inputs[0]

    lib_link_action = lib_target_subject.action_generating(lib_file.short_path)
    lib_link_action.mnemonic().equals("CppLink")

    # Construct library LTO paths
    library_lto_dir = "{package}/{test_name}/liblib.so.lto".format(
        package = package,
        test_name = test_name,
    )
    lib_obj_path = "{library_lto_dir}/{bindir}/{package}/_objs/{lib_target_name}/bye.pic.o".format(
        library_lto_dir = library_lto_dir,
        bindir = bindir,
        package = package,
        lib_target_name = lib_target_name,
    )
    lib_params_path = "{package}/{test_name}/liblib.so-lto-final.params".format(
        package = package,
        test_name = test_name,
    )
    binary_obj_path = "{package}/{name}.lto/{bindir}/{package}/_objs/{name}/hello.pic.o".format(
        package = package,
        name = name,
        bindir = bindir,
    )
    params_path = "{package}/{name}-lto-final.params".format(
        package = package,
        name = name,
    )

    # Binary link action assertions
    link_action.inputs().contains(binary_obj_path)
    link_action.inputs().contains(solib_file.short_path)
    link_action.inputs().contains(params_path)

    # Check argv for binary link
    link_action.argv().contains("-Wl,@{bindir}/{params_path}".format(
        bindir = bindir,
        params_path = params_path,
    ))

    # Check that all our _objs args (except linkstamp) are in LTO dir
    lto_dir = "{package}/{name}.lto".format(package = package, name = name)
    objs_args = link_action.argv().transform(
        desc = "object arguments",
        filter = lambda arg: "_objs" in arg and "linkstamp" not in arg and package in arg,
    )
    bad_args = objs_args.transform(
        desc = "object arguments not using LTO paths",
        filter = lambda arg: lto_dir not in arg,
    )
    bad_args.is_empty()

    # Library LTO backend action
    lib_backend_action = lib_target_subject.action_generating(lib_obj_path)
    lib_backend_action.mnemonic().equals("CcLtoBackendCompile")
    lib_backend_action.inputs().contains(lib_obj_path + ".thinlto.bc")

    # Library backend argv
    lib_thinlto_index_arg = "thinlto_index={bindir}/{lib_obj_path}.thinlto.bc".format(
        bindir = bindir,
        lib_obj_path = lib_obj_path,
    )
    lib_thinlto_output_arg = "thinlto_output_object_file={bindir}/{lib_obj_path}".format(
        bindir = bindir,
        lib_obj_path = lib_obj_path,
    )
    lib_thinlto_input_arg = "thinlto_input_bitcode_file={bindir}/{package}/_objs/{lib_target_name}/bye.pic.o".format(
        bindir = bindir,
        package = package,
        lib_target_name = lib_target_name,
    )
    lib_backend_action.argv().contains_at_least([
        lib_thinlto_index_arg,
        lib_thinlto_output_arg,
        lib_thinlto_input_arg,
    ])

    # Library Index action
    lib_index_action = lib_target_subject.action_generating(lib_obj_path + ".thinlto.bc")
    lib_index_action.mnemonic().equals("CppLTOIndexing")

    lib_index_outputs = env.expect.that_depset_of_files(lib_index_action.actual.outputs)
    lib_index_outputs.contains(lib_obj_path + ".imports")
    lib_index_outputs.contains(lib_obj_path + ".thinlto.bc")
    lib_index_outputs.contains(lib_params_path)

    lib_indexing_obj = "{package}/_objs/{lib_target_name}/bye.pic.indexing.o".format(
        package = package,
        lib_target_name = lib_target_name,
    )
    lib_index_action.inputs().contains(lib_indexing_obj)

    # Library bitcode action
    lib_bitcode_action = lib_target_subject.action_generating(lib_indexing_obj)
    lib_bitcode_action.mnemonic().equals("CppCompile")
    lib_bitcode_action.argv().contains(
        "lto_indexing_bitcode={bindir}/{lib_indexing_obj}".format(
            bindir = bindir,
            lib_indexing_obj = lib_indexing_obj,
        ),
    )

def _test_thin_lto_backend_env(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/lib",
        srcs = ["bye.cc"],
        hdrs = ["bye.h"],
    )
    util.helper_target(
        cc_binary,
        name = name + "/bin",
        srcs = ["hello.cc"],
        deps = [":" + name + "/lib"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_thin_lto_backend_env_impl,
        target = name + "/bin",
        test_features = ["thin_lto", "supports_pic", "supports_start_end_lib", "env_feature", "static_env_feature", "module_maps"],
        **kwargs
    )

def _test_thin_lto_backend_env_impl(env, target):
    package = target.label.package
    name = target.label.name
    bindir = target[TestingAspectInfo].bin_path

    binary_obj_path = "{package}/{name}.lto/{bindir}/{package}/_objs/{name}/hello.pic.o".format(
        package = package,
        name = name,
        bindir = bindir,
    )

    backend_action = env.expect.that_target(target).action_generating(binary_obj_path)
    backend_action.mnemonic().equals("CcLtoBackendCompile")
    backend_action.env().contains_at_least({"cat": "meow"})

def _test_thin_lto_fission(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/lib",
        srcs = ["bye.cc"],
        hdrs = ["bye.h"],
    )
    util.helper_target(
        cc_binary,
        name = name + "/bin",
        srcs = ["hello.cc"],
        deps = [":" + name + "/lib"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_thin_lto_fission_impl,
        target = name + "/bin",
        test_features = ["thin_lto", "supports_pic", "supports_start_end_lib", "per_object_debug_info"],
        config_settings = {
            "//command_line_option:fission": ["yes"],
            "//command_line_option:copt": ["-g0"],
        },
        **kwargs
    )

def _test_thin_lto_fission_impl(env, target):
    package = target.label.package
    name = target.label.name
    bindir = target[TestingAspectInfo].bin_path

    test_name = name.split("/")[0]
    lib_target_name = test_name + "/lib"

    # Binary LTO backend
    binary_obj_path = "{package}/{name}.lto/{bindir}/{package}/_objs/{name}/hello.pic.o".format(
        package = package,
        name = name,
        bindir = bindir,
    )
    binary_dwo_path = "{package}/{name}.lto/{bindir}/{package}/_objs/{name}/hello.pic.dwo".format(
        package = package,
        name = name,
        bindir = bindir,
    )

    backend_action = env.expect.that_target(target).action_generating(binary_obj_path)
    backend_action.mnemonic().equals("CcLtoBackendCompile")

    backend_outputs = env.expect.that_depset_of_files(backend_action.actual.outputs)
    backend_outputs.contains_exactly([binary_obj_path, binary_dwo_path])
    backend_action.argv().contains_at_least(["-g0", "per_object_debug_info_option"])

    # Library LTO backend (static linking, so in binary's LTO dir)
    lib_obj_path = "{package}/{name}.lto/{bindir}/{package}/_objs/{lib_target_name}/bye.pic.o".format(
        package = package,
        name = name,
        bindir = bindir,
        lib_target_name = lib_target_name,
    )
    lib_dwo_path = "{package}/{name}.lto/{bindir}/{package}/_objs/{lib_target_name}/bye.pic.dwo".format(
        package = package,
        name = name,
        bindir = bindir,
        lib_target_name = lib_target_name,
    )

    lib_backend_action = env.expect.that_target(target).action_generating(lib_obj_path)
    lib_backend_action.mnemonic().equals("CcLtoBackendCompile")

    lib_backend_outputs = env.expect.that_depset_of_files(lib_backend_action.actual.outputs)
    lib_backend_outputs.contains_exactly([lib_obj_path, lib_dwo_path])
    lib_backend_action.argv().contains("per_object_debug_info_option")

    # DWP action
    dwp_file_path = "{package}/{name}.dwp".format(
        package = package,
        name = name,
    )
    dwp_action = env.expect.that_target(target).action_generating(dwp_file_path)
    dwp_action.mnemonic().equals("CcGenerateDwp")

    dwp_inputs = dwp_action.actual.inputs.to_list()
    inter_dwps = [f for f in dwp_inputs if f.extension == "dwp"]
    _verify_dwos_in_dwp(env, dwp_action, [target], ["hello.pic.dwo", "bye.pic.dwo"])

    # Verify final DWP action arguments
    if inter_dwps:
        some_inter_dwp_arg = "{bindir}/{package}/_dwps/{package}/{name}-1.dwp".format(
            bindir = bindir,
            package = package,
            name = name,
        )
        dwp_action.argv().contains(some_inter_dwp_arg)
    else:
        dwp_action.argv().contains("{bindir}/{binary_dwo_path}".format(bindir = bindir, binary_dwo_path = binary_dwo_path))
        dwp_action.argv().contains("{bindir}/{lib_dwo_path}".format(bindir = bindir, lib_dwo_path = lib_dwo_path))

    dwp_action.argv().contains_at_least(["-o", "{bindir}/{dwp_file_path}".format(bindir = bindir, dwp_file_path = dwp_file_path)]).in_order()

def _test_thin_lto_no_linkstatic_fission(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/lib",
        srcs = ["bye.cc"],
        hdrs = ["bye.h"],
    )
    util.helper_target(
        cc_binary,
        name = name + "/bin",
        srcs = ["hello.cc"],
        deps = [":" + name + "/lib"],
        linkstatic = 0,
    )
    cc_analysis_test(
        name = name,
        impl = _test_thin_lto_no_linkstatic_fission_impl,
        targets = {
            "bin": name + "/bin",
            "lib": name + "/lib",
        },
        test_features = [
            "thin_lto",
            "supports_pic",
            "supports_start_end_lib",
            "supports_dynamic_linker",
            "supports_interface_shared_libraries",
            "per_object_debug_info",
        ],
        config_settings = {
            "//command_line_option:fission": ["yes"],
        },
        **kwargs
    )

def _test_thin_lto_no_linkstatic_fission_impl(env, targets):
    bin_target = targets.bin
    lib_target = targets.lib

    package = bin_target.label.package
    name = bin_target.label.name
    bindir = bin_target[TestingAspectInfo].bin_path

    test_name = name.split("/")[0]
    lib_target_name = test_name + "/lib"

    # Library LTO backend
    library_lto_dir = "{package}/{test_name}/liblib.so.lto".format(
        package = package,
        test_name = test_name,
    )
    lib_obj_path = "{library_lto_dir}/{bindir}/{package}/_objs/{lib_target_name}/bye.pic.o".format(
        library_lto_dir = library_lto_dir,
        bindir = bindir,
        package = package,
        lib_target_name = lib_target_name,
    )
    lib_dwo_path = "{library_lto_dir}/{bindir}/{package}/_objs/{lib_target_name}/bye.pic.dwo".format(
        library_lto_dir = library_lto_dir,
        bindir = bindir,
        package = package,
        lib_target_name = lib_target_name,
    )

    lib_target_subject = env.expect.that_target(lib_target)
    lib_backend_action = lib_target_subject.action_generating(lib_obj_path)
    lib_backend_action.mnemonic().equals("CcLtoBackendCompile")

    lib_backend_outputs = env.expect.that_depset_of_files(lib_backend_action.actual.outputs)
    lib_backend_outputs.contains_exactly([lib_obj_path, lib_dwo_path])

    # Binary LTO backend
    binary_obj_path = "{package}/{name}.lto/{bindir}/{package}/_objs/{name}/hello.pic.o".format(
        package = package,
        name = name,
        bindir = bindir,
    )
    binary_dwo_path = "{package}/{name}.lto/{bindir}/{package}/_objs/{name}/hello.pic.dwo".format(
        package = package,
        name = name,
        bindir = bindir,
    )
    binary_backend_action = env.expect.that_target(bin_target).action_generating(binary_obj_path)
    binary_backend_outputs = env.expect.that_depset_of_files(binary_backend_action.actual.outputs)
    binary_backend_outputs.contains_exactly([binary_obj_path, binary_dwo_path])

    # DWP action
    dwp_file_path = "{package}/{name}.dwp".format(
        package = package,
        name = name,
    )
    dwp_action = env.expect.that_target(bin_target).action_generating(dwp_file_path)
    dwp_action.mnemonic().equals("CcGenerateDwp")

    # Assert binary dwo is input, but library dwo is NOT
    dwp_action.inputs().contains(binary_dwo_path)
    dwp_action.inputs().not_contains(lib_dwo_path)

    # Assert argv
    binary_dwo_arg = "{bindir}/{binary_dwo_path}".format(bindir = bindir, binary_dwo_path = binary_dwo_path)
    lib_dwo_arg = "{bindir}/{lib_dwo_path}".format(bindir = bindir, lib_dwo_path = lib_dwo_path)

    dwp_action.argv().contains(binary_dwo_arg)
    dwp_action.argv().not_contains(lib_dwo_arg)
    dwp_action.argv().contains_at_least(["-o", "{bindir}/{dwp_file_path}".format(bindir = bindir, dwp_file_path = dwp_file_path)]).in_order()

def _test_thin_lto_linkstatic_cc_test_fission(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/lib",
        srcs = ["bye.cc"],
        hdrs = ["bye.h"],
        linkstamp = "linkstamp.cc",
    )
    util.helper_target(
        cc_test,
        name = name + "/bin_test",
        srcs = ["hello.cc"],
        deps = [":" + name + "/lib"],
        linkstatic = 1,
    )
    cc_analysis_test(
        name = name,
        impl = _test_thin_lto_linkstatic_cc_test_fission_impl,
        targets = {
            "bin": name + "/bin_test",
            "lib": name + "/lib",
        },
        test_features = [
            "thin_lto",
            "supports_pic",
            "supports_start_end_lib",
            "per_object_debug_info",
            "thin_lto_linkstatic_tests_use_shared_nonlto_backends",
        ],
        config_settings = {
            "//command_line_option:fission": ["yes"],
        },
        **kwargs
    )

def _test_thin_lto_linkstatic_cc_test_fission_impl(env, targets):
    bin_target = targets.bin
    lib_target = targets.lib

    package = bin_target.label.package
    name = bin_target.label.name
    bindir = bin_target[TestingAspectInfo].bin_path

    test_name = name.split("/")[0]
    lib_target_name = test_name + "/lib"

    # All backends should be shared non-LTO in this case.
    binary_obj_path = "shared.nonlto/{bindir}/{package}/_objs/{name}/hello.pic.o".format(
        bindir = bindir,
        package = package,
        name = name,
    )
    binary_dwo_path = "shared.nonlto/{bindir}/{package}/_objs/{name}/hello.pic.dwo".format(
        bindir = bindir,
        package = package,
        name = name,
    )

    backend_action = env.expect.that_target(bin_target).action_generating(binary_obj_path)
    backend_action.mnemonic().equals("CcLtoBackendCompile")

    backend_outputs = env.expect.that_depset_of_files(backend_action.actual.outputs)
    backend_outputs.contains_exactly([binary_obj_path, binary_dwo_path])
    backend_action.argv().contains("per_object_debug_info_option")

    # Library backend
    lib_obj_path = "shared.nonlto/{bindir}/{package}/_objs/{lib_target_name}/bye.pic.o".format(
        bindir = bindir,
        package = package,
        lib_target_name = lib_target_name,
    )
    lib_dwo_path = "shared.nonlto/{bindir}/{package}/_objs/{lib_target_name}/bye.pic.dwo".format(
        bindir = bindir,
        package = package,
        lib_target_name = lib_target_name,
    )

    # Query from lib_target instead of bin_target
    lib_backend_action = env.expect.that_target(lib_target).action_generating(lib_obj_path)
    lib_backend_action.mnemonic().equals("CcLtoBackendCompile")
    lib_backend_action.argv().contains("-fPIC")

    lib_backend_outputs = env.expect.that_depset_of_files(lib_backend_action.actual.outputs)
    lib_backend_outputs.contains_exactly([lib_obj_path, lib_dwo_path])
    lib_backend_action.argv().contains("per_object_debug_info_option")

    # DWP action
    dwp_file_path = "{package}/{name}.dwp".format(
        package = package,
        name = name,
    )
    dwp_action = env.expect.that_target(bin_target).action_generating(dwp_file_path)
    dwp_action.mnemonic().equals("CcGenerateDwp")

    dwp_inputs = dwp_action.actual.inputs.to_list()
    inter_dwps = [f for f in dwp_inputs if f.extension == "dwp"]

    # We need to search actions in both bin and lib targets because the library's
    # DWP action (or intermediate DWP actions) might be registered on lib?
    # Actually, intermediate DWP actions for the binary's DWP are created by the binary.
    # So they should be on bin_target.
    # But let's check.
    _verify_dwos_in_dwp(env, dwp_action, [bin_target, lib_target], ["hello.pic.dwo", "bye.pic.dwo"])

    # Verify final DWP action arguments
    if inter_dwps:
        some_inter_dwp_arg = "{bindir}/{package}/_dwps/{package}/{name}-1.dwp".format(
            bindir = bindir,
            package = package,
            name = name,
        )
        dwp_action.argv().contains(some_inter_dwp_arg)
    else:
        dwp_action.argv().contains("{bindir}/{binary_dwo_path}".format(bindir = bindir, binary_dwo_path = binary_dwo_path))
        dwp_action.argv().contains("{bindir}/{lib_dwo_path}".format(bindir = bindir, lib_dwo_path = lib_dwo_path))

    dwp_action.argv().contains_at_least(["-o", "{bindir}/{dwp_file_path}".format(bindir = bindir, dwp_file_path = dwp_file_path)]).in_order()

def _find_action(targets, short_path):
    for t in targets:
        if TestingAspectInfo in t:
            for action in t[TestingAspectInfo].actions:
                for output in action.outputs.to_list():
                    if output.short_path == short_path:
                        return action
    return None

def _verify_dwos_in_dwp(env, dwp_action, targets, expected_dwos):
    dwo_found = {dwo: False for dwo in expected_dwos}

    dwp_inputs = dwp_action.actual.inputs.to_list()
    inter_dwps = [f for f in dwp_inputs if f.extension == "dwp"]

    if inter_dwps:
        for inter_file in inter_dwps:
            action = _find_action(targets, inter_file.short_path)
            if action:
                inputs = action.inputs.to_list()
                for f in inputs:
                    for dwo in expected_dwos:
                        if dwo in f.path:
                            dwo_found[dwo] = True
    else:
        for f in dwp_inputs:
            for dwo in expected_dwos:
                if dwo in f.path:
                    dwo_found[dwo] = True

    expected_dict = {dwo: True for dwo in expected_dwos}
    env.expect.that_dict(dwo_found).contains_exactly(expected_dict)

def _test_linkstatic_cc_test(name, **kwargs):
    util.helper_target(
        cc_library,
        name = name + "/lib",
        srcs = ["bye.cc"],
        hdrs = ["bye.h"],
        linkstamp = "linkstamp.cc",
    )
    util.helper_target(
        cc_test,
        name = name + "/bin_test",
        srcs = ["hello.cc"],
        deps = [":" + name + "/lib"],
        linkstatic = 1,
    )
    util.helper_target(
        cc_test,
        name = name + "/bin_test2",
        srcs = ["hello.cc"],
        deps = [":" + name + "/lib"],
        linkstatic = 1,
    )
    cc_analysis_test(
        name = name,
        impl = _test_linkstatic_cc_test_impl,
        targets = {
            "bin1": name + "/bin_test",
            "bin2": name + "/bin_test2",
            "lib": name + "/lib",
        },
        test_features = [
            "thin_lto",
            "supports_pic",
            "supports_start_end_lib",
            "thin_lto_linkstatic_tests_use_shared_nonlto_backends",
            "per_object_debug_info",
            "user_compile_flags",
        ],
        config_settings = {
            "//command_line_option:linkopt": ["alinkopt"],
        },
        **kwargs
    )

def _test_linkstatic_cc_test_impl(env, targets):
    bin1_target = targets.bin1
    bin2_target = targets.bin2
    lib_target = targets.lib

    package = bin1_target.label.package
    bin1_name = bin1_target.label.name
    bin2_name = bin2_target.label.name
    lib_name = lib_target.label.name
    bindir = bin1_target[TestingAspectInfo].bin_path

    lib_obj_path = "shared.nonlto/{bindir}/{package}/_objs/{lib_target_name}/bye.pic.o".format(
        bindir = bindir,
        package = package,
        lib_target_name = lib_name,
    )

    bin1_obj_path = "shared.nonlto/{bindir}/{package}/_objs/{bin1_target_name}/hello.pic.o".format(
        bindir = bindir,
        package = package,
        bin1_target_name = bin1_name,
    )

    bin1_backend_action = env.expect.that_target(bin1_target).action_generating(bin1_obj_path)
    bin1_backend_action.mnemonic().equals("CcLtoBackendCompile")
    bin1_backend_action.argv().not_contains("alinkopt")

    lib_backend_action = env.expect.that_target(lib_target).action_generating(lib_obj_path)
    lib_backend_action.mnemonic().equals("CcLtoBackendCompile")
    lib_backend_action.argv().contains("-fPIC")
    lib_backend_action.argv().not_contains("alinkopt")

    bin1_subject = cc_binary_target_subject.from_target(env, bin1_target)
    bin1_executable = "{package}/{name}".format(package = package, name = bin1_name)
    bin1_link_action = bin1_subject.action_generating(bin1_executable)
    bin1_link_action.inputs().contains(lib_obj_path)

    bin2_subject = cc_binary_target_subject.from_target(env, bin2_target)
    bin2_executable = "{package}/{name}".format(package = package, name = bin2_name)
    bin2_link_action = bin2_subject.action_generating(bin2_executable)
    bin2_link_action.inputs().contains(lib_obj_path)

def _test_test_only_target(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/bin",
        srcs = ["hello.cc"],
        testonly = 1,
    )
    cc_analysis_test(
        name = name,
        impl = _test_test_only_target_impl,
        target = name + "/bin",
        test_features = [
            "thin_lto",
            "supports_pic",
            "supports_start_end_lib",
            "thin_lto_linkstatic_tests_use_shared_nonlto_backends",
            "user_compile_flags",
        ],
        config_settings = {
            "//command_line_option:linkopt": ["alinkopt"],
        },
        **kwargs
    )

def _test_test_only_target_impl(env, target):
    package = target.label.package
    name = target.label.name
    bindir = target[TestingAspectInfo].bin_path

    obj_path = "shared.nonlto/{bindir}/{package}/_objs/{name}/hello.pic.o".format(
        bindir = bindir,
        package = package,
        name = name,
    )

    backend_action = env.expect.that_target(target).action_generating(obj_path)
    backend_action.mnemonic().equals("CcLtoBackendCompile")
    backend_action.argv().not_contains("alinkopt")

def _test_use_shared_all_linkstatic(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/bin",
        srcs = ["hello.cc"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_use_shared_all_linkstatic_impl,
        target = name + "/bin",
        test_features = [
            "thin_lto",
            "supports_pic",
            "supports_start_end_lib",
            "thin_lto_all_linkstatic_use_shared_nonlto_backends",
            "user_compile_flags",
        ],
        config_settings = {
            "//command_line_option:linkopt": ["alinkopt"],
        },
        **kwargs
    )

def _test_use_shared_all_linkstatic_impl(env, target):
    package = target.label.package
    name = target.label.name
    bindir = target[TestingAspectInfo].bin_path

    obj_path = "shared.nonlto/{bindir}/{package}/_objs/{name}/hello.pic.o".format(
        bindir = bindir,
        package = package,
        name = name,
    )

    backend_action = env.expect.that_target(target).action_generating(obj_path)
    backend_action.mnemonic().equals("CcLtoBackendCompile")
    backend_action.argv().not_contains("alinkopt")

def _test_assembler_source(name, **kwargs):
    s_file = util.empty_file(name + "_tracing.S")
    util.helper_target(
        cc_library,
        name = name + "/lib",
        srcs = ["bye.cc", s_file],
        hdrs = ["bye.h"],
    )
    util.helper_target(
        cc_binary,
        name = name + "/bin",
        srcs = ["hello.cc"],
        deps = [":" + name + "/lib"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_assembler_source_impl,
        targets = {
            "bin": name + "/bin",
            "lib": name + "/lib",
        },
        test_features = ["thin_lto", "supports_pic", "supports_start_end_lib"],
        **kwargs
    )

def _test_assembler_source_impl(env, targets):
    bin_target = targets.bin
    lib_target = targets.lib

    package = bin_target.label.package
    name = bin_target.label.name

    test_name = name.split("/")[0]
    lib_target_name = test_name + "/lib"
    s_file_name = test_name + "_tracing"

    obj_path = "{package}/_objs/{lib_target_name}/{s_file_name}.pic.o".format(
        package = package,
        lib_target_name = lib_target_name,
        s_file_name = s_file_name,
    )

    compile_action = env.expect.that_target(lib_target).action_generating(obj_path)
    compile_action.mnemonic().equals("CppCompile")

    binary_target = cc_binary_target_subject.from_target(env, bin_target)
    link_action = binary_target.action_generating("{package}/{name}{binary_extension}")
    link_action.inputs().contains(obj_path)

# Make sure we don't choke on a cc_library without sources and therefore, without bitcode files.
def _test_no_source_files(name, **kwargs):
    a_file = util.empty_file(name + "_static.a")
    util.helper_target(
        cc_library,
        name = name + "/lib",
        srcs = [a_file],
    )
    util.helper_target(
        cc_binary,
        name = name + "/bin",
        srcs = ["hello.cc"],
        deps = [":" + name + "/lib"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_no_source_files_impl,
        target = name + "/bin",
        test_features = ["thin_lto", "supports_pic", "supports_start_end_lib"],
        **kwargs
    )

def _test_no_source_files_impl(env, target):
    env.expect.that_str(target.label.name).ends_with("bin")

def _test_fdo_instrument(name, **kwargs):
    util.helper_target(
        cc_binary,
        name = name + "/bin",
        srcs = ["hello.cc"],
    )
    cc_analysis_test(
        name = name,
        impl = _test_fdo_instrument_impl,
        target = name + "/bin",
        test_features = ["thin_lto", "supports_pic", "supports_start_end_lib"],
        with_features = ["thin_lto", "supports_pic", "supports_start_end_lib", "fdo_instrument"],
        config_settings = {
            "//command_line_option:fdo_instrument": "profiles",
        },
        **kwargs
    )

def _test_fdo_instrument_impl(env, target):
    package = target.label.package
    name = target.label.name
    bindir = target[TestingAspectInfo].bin_path

    obj_path = "{package}/{name}.lto/{bindir}/{package}/_objs/{name}/hello.pic.o".format(
        package = package,
        name = name,
        bindir = bindir,
    )

    backend_action = env.expect.that_target(target).action_generating(obj_path)
    backend_action.mnemonic().equals("CcLtoBackendCompile")

    # If the LtoBackendAction incorrectly tries to add the fdo_instrument
    # feature, we will fail with an "unknown variable 'fdo_instrument_path'"
    # error. But let's also explicitly confirm that the fdo_instrument
    # option didn't end up here.
    backend_action.argv().not_contains("fdo_instrument_option")

def _create_thin_lto_basic_targets(name):
    util.helper_target(
        cc_library,
        name = name + "/lib",
        srcs = ["libfile.cc"],
        hdrs = ["libfile.h"],
        linkstamp = "linkstamp.cc",
    )
    util.helper_target(
        cc_binary,
        name = name + "/bin",
        srcs = ["binfile.cc"],
        deps = [":" + name + "/lib"],
    )

def _test_lto_index_opt(name, **kwargs):
    _create_thin_lto_basic_targets(name)
    cc_analysis_test(
        name = name,
        impl = _test_lto_index_opt_impl,
        target = name + "/bin",
        test_features = ["thin_lto", "supports_pic", "supports_start_end_lib"],
        config_settings = {
            "//command_line_option:ltoindexopt": ["anltoindexopt"],
        },
        **kwargs
    )

def _test_lto_index_opt_impl(env, target):
    package = target.label.package
    name = target.label.name
    bindir = target[TestingAspectInfo].bin_path

    binary_obj_path = "{package}/{name}.lto/{bindir}/{package}/_objs/{name}/binfile.pic.o".format(
        package = package,
        name = name,
        bindir = bindir,
    )

    index_action = env.expect.that_target(target).action_generating(binary_obj_path + ".thinlto.bc")
    index_action.mnemonic().equals("CppLTOIndexing")
    index_action.argv().contains("anltoindexopt")

def _test_lto_standalone_command_lines(name, **kwargs):
    _create_thin_lto_basic_targets(name)
    cc_analysis_test(
        name = name,
        impl = _test_lto_standalone_command_lines_impl,
        target = name + "/bin",
        test_features = ["thin_lto", "supports_pic", "supports_start_end_lib"],
        config_settings = {
            "//command_line_option:ltoindexopt": ["anltoindexopt"],
        },
        **kwargs
    )

def _test_lto_standalone_command_lines_impl(env, target):
    package = target.label.package
    name = target.label.name
    bindir = target[TestingAspectInfo].bin_path

    binary_obj_path = "{package}/{name}.lto/{bindir}/{package}/_objs/{name}/binfile.pic.o".format(
        package = package,
        name = name,
        bindir = bindir,
    )

    index_action = env.expect.that_target(target).action_generating(binary_obj_path + ".thinlto.bc")
    index_action.mnemonic().equals("CppLTOIndexing")
    index_action.argv().contains("--i_come_from_standalone_lto_index=anltoindexopt")

def _test_copt(name, **kwargs):
    _create_thin_lto_basic_targets(name)
    cc_analysis_test(
        name = name,
        impl = _test_copt_impl,
        target = name + "/bin",
        test_features = ["thin_lto", "supports_pic", "supports_start_end_lib"],
        config_settings = {
            "//command_line_option:copt": ["acopt"],
        },
        **kwargs
    )

def _test_copt_impl(env, target):
    package = target.label.package
    name = target.label.name
    bindir = target[TestingAspectInfo].bin_path

    binary_obj_path = "{package}/{name}.lto/{bindir}/{package}/_objs/{name}/binfile.pic.o".format(
        package = package,
        name = name,
        bindir = bindir,
    )

    backend_action = env.expect.that_target(target).action_generating(binary_obj_path)
    backend_action.mnemonic().equals("CcLtoBackendCompile")
    backend_action.argv().contains("acopt")

def _test_per_file_copt(name, **kwargs):
    _create_thin_lto_basic_targets(name)
    cc_analysis_test(
        name = name,
        impl = _test_per_file_copt_impl,
        target = name + "/bin",
        test_features = ["thin_lto", "supports_pic", "supports_start_end_lib"],
        config_settings = {
            "//command_line_option:per_file_copt": [
                "binfile\\.cc@copt1",
                "libfile\\.cc@copt2",
                ".*\\.cc,-binfile\\.cc@copt2",
            ],
        },
        **kwargs
    )

def _test_per_file_copt_impl(env, target):
    package = target.label.package
    name = target.label.name
    bindir = target[TestingAspectInfo].bin_path

    test_name = name.split("/")[0]
    lib_target_name = test_name + "/lib"

    binary_obj_path = "{package}/{name}.lto/{bindir}/{package}/_objs/{name}/binfile.pic.o".format(
        package = package,
        name = name,
        bindir = bindir,
    )
    lib_obj_path = "{package}/{name}.lto/{bindir}/{package}/_objs/{lib_target_name}/libfile.pic.o".format(
        package = package,
        name = name,
        bindir = bindir,
        lib_target_name = lib_target_name,
    )

    bin_backend_action = env.expect.that_target(target).action_generating(binary_obj_path)
    bin_backend_action.mnemonic().equals("CcLtoBackendCompile")
    bin_backend_action.argv().contains("copt1")
    bin_backend_action.argv().not_contains("copt2")

    lib_backend_action = env.expect.that_target(target).action_generating(lib_obj_path)
    lib_backend_action.mnemonic().equals("CcLtoBackendCompile")
    lib_backend_action.argv().contains("copt2")
    lib_backend_action.argv().not_contains("copt1")

def _test_lto_backend_opt(name, **kwargs):
    _create_thin_lto_basic_targets(name)
    cc_analysis_test(
        name = name,
        impl = _test_lto_backend_opt_impl,
        target = name + "/bin",
        test_features = ["thin_lto", "supports_pic", "supports_start_end_lib", "user_compile_flags"],
        config_settings = {
            "//command_line_option:ltobackendopt": ["anltobackendopt"],
            "//command_line_option:linkopt": ["alinkopt"],
        },
        **kwargs
    )

def _test_lto_backend_opt_impl(env, target):
    package = target.label.package
    name = target.label.name
    bindir = target[TestingAspectInfo].bin_path

    binary_obj_path = "{package}/{name}.lto/{bindir}/{package}/_objs/{name}/binfile.pic.o".format(
        package = package,
        name = name,
        bindir = bindir,
    )

    backend_action = env.expect.that_target(target).action_generating(binary_obj_path)
    backend_action.mnemonic().equals("CcLtoBackendCompile")
    backend_action.argv().contains_at_least([
        "--default-compile-flag",
        "anltobackendopt",
    ])
    backend_action.argv().not_contains("alinkopt")

def _test_per_file_lto_backend_opt(name, **kwargs):
    _create_thin_lto_basic_targets(name)
    cc_analysis_test(
        name = name,
        impl = _test_per_file_lto_backend_opt_impl,
        target = name + "/bin",
        test_features = ["thin_lto", "supports_pic", "supports_start_end_lib"],
        config_settings = {
            "//command_line_option:per_file_ltobackendopt": [
                "binfile\\.pic\\.o@ltobackendopt1",
                ".*\\.o,-binfile\\.pic\\.o@ltobackendopt2",
            ],
        },
        **kwargs
    )

def _test_per_file_lto_backend_opt_impl(env, target):
    package = target.label.package
    name = target.label.name
    bindir = target[TestingAspectInfo].bin_path

    test_name = name.split("/")[0]
    lib_target_name = test_name + "/lib"

    binary_obj_path = "{package}/{name}.lto/{bindir}/{package}/_objs/{name}/binfile.pic.o".format(
        package = package,
        name = name,
        bindir = bindir,
    )
    lib_obj_path = "{package}/{name}.lto/{bindir}/{package}/_objs/{lib_target_name}/libfile.pic.o".format(
        package = package,
        name = name,
        bindir = bindir,
        lib_target_name = lib_target_name,
    )

    bin_backend_action = env.expect.that_target(target).action_generating(binary_obj_path)
    bin_backend_action.mnemonic().equals("CcLtoBackendCompile")
    bin_backend_action.argv().contains("ltobackendopt1")
    bin_backend_action.argv().not_contains("ltobackendopt2")

    lib_backend_action = env.expect.that_target(target).action_generating(lib_obj_path)
    lib_backend_action.mnemonic().equals("CcLtoBackendCompile")
    lib_backend_action.argv().contains("ltobackendopt2")
    lib_backend_action.argv().not_contains("ltobackendopt1")

def _test_link_opt(name, **kwargs):
    _create_thin_lto_basic_targets(name)
    cc_analysis_test(
        name = name,
        impl = _test_link_opt_impl,
        target = name + "/bin",
        test_features = ["thin_lto", "supports_pic", "supports_start_end_lib"],
        config_settings = {
            "//command_line_option:linkopt": ["alinkopt"],
        },
        **kwargs
    )

def _test_link_opt_impl(env, target):
    package = target.label.package
    name = target.label.name
    bindir = target[TestingAspectInfo].bin_path

    binary_obj_path = "{package}/{name}.lto/{bindir}/{package}/_objs/{name}/binfile.pic.o".format(
        package = package,
        name = name,
        bindir = bindir,
    )

    backend_action = env.expect.that_target(target).action_generating(binary_obj_path)
    backend_action.mnemonic().equals("CcLtoBackendCompile")
    backend_action.argv().not_contains("alinkopt")

def cc_binary_thin_lto_tests(name):
    """TestSuite for cc_binary with ThinLTO.

    Args:
        name: The name of the test suite.
    """
    tests = []

    # These tests pass on all Bazel versions.
    tests.append(_test_thin_lto_action_graph)
    tests.append(_test_thin_lto_no_linkstatic)
    tests.append(_test_thin_lto_fission)
    tests.append(_test_thin_lto_no_linkstatic_fission)
    tests.append(_test_thin_lto_linkstatic_cc_test_fission)
    tests.append(_test_assembler_source)
    tests.append(_test_no_source_files)
    tests.append(_test_fdo_instrument)
    tests.append(_test_lto_index_opt)
    tests.append(_test_copt)
    tests.append(_test_per_file_copt)
    tests.append(_test_per_file_lto_backend_opt)

    # These tests fail on Bazel 7 and 8, run only for Bazel 9+.
    if bazel_features.cc.cc_common_is_in_rules_cc:
        tests.append(_test_thin_lto_linkshared)
        tests.append(_test_thin_lto_backend_env)
        tests.append(_test_linkstatic_cc_test)
        tests.append(_test_test_only_target)
        tests.append(_test_use_shared_all_linkstatic)
        tests.append(_test_lto_standalone_command_lines)
        tests.append(_test_lto_backend_opt)
        tests.append(_test_link_opt)

    test_suite(
        name = name,
        tests = tests,
    )
