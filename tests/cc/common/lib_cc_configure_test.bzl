"""Tests for lib_cc_configure.bzl."""

load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("//cc/private/toolchain:lib_cc_configure.bzl", "split_escaped")  # buildifier: disable=bzl-visibility

def _test_split_escaped(env):
    cases = [
        ("a:b:c", ["a", "b", "c"]),
        ("a%:b", ["a:b"]),
        ("a%%b", ["a%b"]),
        ("a:::b", ["a", "", "", "b"]),
        ("a:b%:c", ["a", "b:c"]),
        ("a%%:b:c", ["a%", "b", "c"]),
        (":a", ["", "a"]),
        ("a:", ["a", ""]),
        ("::a::", ["", "", "a", "", ""]),
        ("%%%:a%%%%:b", ["%:a%%", "b"]),
        ("", []),
        ("%", ["%"]),
        ("%%", ["%"]),
        ("%:", [":"]),
        (":", ["", ""]),
        ("a%:", ["a:"]),
    ]
    for string, expected in cases:
        env.expect.where(
            input = repr(string),
        ).that_collection(
            split_escaped(string, ":"),
        ).contains_exactly(expected).in_order()

def lib_cc_configure_tests(name):
    """Creates the test suite for lib_cc_configure.bzl tests.

    Args:
        name: The name of the test suite.
    """
    test_suite(
        name = name,
        basic_tests = [
            _test_split_escaped,
        ],
    )
