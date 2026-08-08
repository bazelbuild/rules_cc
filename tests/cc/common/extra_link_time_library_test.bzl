"""Tests for extra link-time library creation and merging."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//cc/common:cc_common.bzl", "cc_common")

def _build_extra_link_time_library(_ctx, _static_mode, _for_dynamic_library, **_kwargs):
    return None

def _library_key_collections_are_hashable_tuples_impl(ctx):
    env = unittest.begin(ctx)
    first_library = cc_common.create_extra_link_time_library(
        build_library_func = _build_extra_link_time_library,
        first_constant = "first",
        inputs = depset(["first-input"]),
        second_constant = "second",
    )
    second_library = cc_common.create_extra_link_time_library(
        build_library_func = _build_extra_link_time_library,
        first_constant = "first",
        inputs = depset(["second-input"]),
        second_constant = "second",
    )

    asserts.equals(env, "tuple", type(first_library._key.constant_fields))
    asserts.equals(env, ("first_constant", "second_constant"), first_library._key.constant_fields)
    asserts.equals(env, "tuple", type(first_library._key.depset_fields))
    asserts.equals(env, ("inputs",), first_library._key.depset_fields)

    values_by_key = {first_library._key: "value"}
    asserts.equals(env, "value", values_by_key[second_library._key])
    return unittest.end(env)

_library_key_collections_are_hashable_tuples_test = unittest.make(
    _library_key_collections_are_hashable_tuples_impl,
)

def _empty_and_singleton_libraries_are_tuples_impl(ctx):
    env = unittest.begin(ctx)
    empty_libraries = cc_common.create_linking_context(
        linker_inputs = depset(),
    )._extra_link_time_libraries
    asserts.equals(env, "tuple", type(empty_libraries.libraries))
    asserts.equals(env, (), empty_libraries.libraries)

    library = cc_common.create_extra_link_time_library(
        build_library_func = _build_extra_link_time_library,
    )
    singleton_libraries = cc_common.create_linking_context(
        linker_inputs = depset(),
        extra_link_time_library = library,
    )._extra_link_time_libraries
    asserts.equals(env, "tuple", type(singleton_libraries.libraries))
    asserts.equals(env, (library,), singleton_libraries.libraries)
    return unittest.end(env)

_empty_and_singleton_libraries_are_tuples_test = unittest.make(
    _empty_and_singleton_libraries_are_tuples_impl,
)

def _merged_libraries_are_tuples_impl(ctx):
    env = unittest.begin(ctx)
    first_library = cc_common.create_extra_link_time_library(
        build_library_func = _build_extra_link_time_library,
        inputs = depset(["first-input"]),
        mode = "constant",
    )
    second_library = cc_common.create_extra_link_time_library(
        build_library_func = _build_extra_link_time_library,
        inputs = depset(["second-input"]),
        mode = "constant",
    )

    merged_libraries = cc_common.merge_linking_contexts(
        linking_contexts = [
            cc_common.create_linking_context(
                linker_inputs = depset(),
                extra_link_time_library = first_library,
            ),
            cc_common.create_linking_context(
                linker_inputs = depset(),
                extra_link_time_library = second_library,
            ),
        ],
    )._extra_link_time_libraries

    asserts.equals(env, "tuple", type(merged_libraries.libraries))
    asserts.equals(env, 1, len(merged_libraries.libraries))
    merged_library = merged_libraries.libraries[0]
    asserts.equals(env, "constant", merged_library.mode)
    asserts.equals(env, ["first-input", "second-input"], merged_library.inputs.to_list())
    return unittest.end(env)

_merged_libraries_are_tuples_test = unittest.make(_merged_libraries_are_tuples_impl)

def extra_link_time_library_tests(name):
    if bazel_features.cc.cc_common_is_in_rules_cc:
        unittest.suite(
            name,
            _library_key_collections_are_hashable_tuples_test,
            _empty_and_singleton_libraries_are_tuples_test,
            _merged_libraries_are_tuples_test,
        )
    else:
        native.test_suite(name = name)
