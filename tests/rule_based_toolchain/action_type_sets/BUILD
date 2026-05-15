load(":action_type_set_diff_test.bzl", "action_type_set_diff_test")

# When an action type set is updated, all affected goldens must be updated as well. This makes it easier
# to review structural changes.

action_type_set_diff_test(
    name = "ar_actions_test",
    action_type_set = "//cc/toolchains/actions:ar_actions",
    expected = "//tests/rule_based_toolchain/action_type_sets:goldens/ar_actions.txt",
)

action_type_set_diff_test(
    name = "assembly_actions_test",
    action_type_set = "//cc/toolchains/actions:assembly_actions",
    expected = "//tests/rule_based_toolchain/action_type_sets:goldens/assembly_actions.txt",
)

action_type_set_diff_test(
    name = "c_compile_actions_test",
    action_type_set = "//cc/toolchains/actions:c_compile_actions",
    expected = "//tests/rule_based_toolchain/action_type_sets:goldens/c_compile_actions.txt",
)

action_type_set_diff_test(
    name = "cpp_compile_without_header_parsing_test",
    action_type_set = "//cc/toolchains/actions:cpp_compile_without_header_parsing",
    expected = "//tests/rule_based_toolchain/action_type_sets:goldens/cpp_compile_without_header_parsing.txt",
)

action_type_set_diff_test(
    name = "cpp_compile_actions_test",
    action_type_set = "//cc/toolchains/actions:cpp_compile_actions",
    expected = "//tests/rule_based_toolchain/action_type_sets:goldens/cpp_compile_actions.txt",
)

action_type_set_diff_test(
    name = "compile_actions_without_header_parsing_test",
    action_type_set = "//cc/toolchains/actions:compile_actions_without_header_parsing",
    expected = "//tests/rule_based_toolchain/action_type_sets:goldens/compile_actions_without_header_parsing.txt",
)

action_type_set_diff_test(
    name = "source_compile_actions_test",
    action_type_set = "//cc/toolchains/actions:source_compile_actions",
    expected = "//tests/rule_based_toolchain/action_type_sets:goldens/source_compile_actions.txt",
)

action_type_set_diff_test(
    name = "compile_actions_test",
    action_type_set = "//cc/toolchains/actions:compile_actions",
    expected = "//tests/rule_based_toolchain/action_type_sets:goldens/compile_actions.txt",
)

action_type_set_diff_test(
    name = "link_executable_actions_test",
    action_type_set = "//cc/toolchains/actions:link_executable_actions",
    expected = "//tests/rule_based_toolchain/action_type_sets:goldens/link_executable_actions.txt",
)

action_type_set_diff_test(
    name = "dynamic_library_link_actions_test",
    action_type_set = "//cc/toolchains/actions:dynamic_library_link_actions",
    expected = "//tests/rule_based_toolchain/action_type_sets:goldens/dynamic_library_link_actions.txt",
)

action_type_set_diff_test(
    name = "nodeps_dynamic_library_link_actions_test",
    action_type_set = "//cc/toolchains/actions:nodeps_dynamic_library_link_actions",
    expected = "//tests/rule_based_toolchain/action_type_sets:goldens/nodeps_dynamic_library_link_actions.txt",
)

action_type_set_diff_test(
    name = "link_actions_test",
    action_type_set = "//cc/toolchains/actions:link_actions",
    expected = "//tests/rule_based_toolchain/action_type_sets:goldens/link_actions.txt",
)

action_type_set_diff_test(
    name = "transitive_link_actions_test",
    action_type_set = "//cc/toolchains/actions:transitive_link_actions",
    expected = "//tests/rule_based_toolchain/action_type_sets:goldens/transitive_link_actions.txt",
)

action_type_set_diff_test(
    name = "all_actions_test",
    action_type_set = "//cc/toolchains/actions:all_actions",
    expected = "//tests/rule_based_toolchain/action_type_sets:goldens/all_actions.txt",
)
