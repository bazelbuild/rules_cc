# CC Toolchain Features

This document covers the special strings used by bazel / `rules_cc` to
configure cc toolchains behavior. This is useful for flipping specific
behavior on or off for your project, or for writing your own toolchain.

NOTE: It's possible this document has drifted, please file issues or
submit PRs for any inaccuracies you find

## Toolchain features

CC toolchains are configured by creating features. Features are
arbitrary strings for enabling or disabling behavior in the toolchain.

Semantically there are 2 types of special features:

1. Features which are just markers to bazel / `rules_cc` that some
   behavior should be enabled or is supported by the toolchain
2. Features which whose name is special, but also is expected to pass
   the various compiler / linker flags to enable the behavior.

With all features, even though the feature name may have special
behavior, it is still up to your toolchain to provide the correct
compiler flags.

NOTE: Feature names aren't really considered public API, and are subject
to change more frequently than the rest of the API (even though their
behavior likely doesn't change often).

NOTE: While this document attempts to cover `rules_cc` behavior, it is
possible for any custom rule to read the features of the toolchain and
change its behavior based on them.

## Toolchain variables

In order to read this document, you should be familiar with the concept
of toolchain variables separately from features. One of the ways that
`rules_cc` controls toolchain behavior is by passing values through
"variables". These are read by the toolchain through the functions such
as `expand_if_available` (to see if a boolean is set or a string is
non-empty) and `iterate_over` (to loop over an array of values, such as
include paths). These variables often use the same strings as the
feature names, which can lead to some confusion in this document.

For example the `pic` feature (discussed below) is a special feature
name that also reads the `pic` variable, which is a special variable
name set by `rules_cc`. The fact that the same string is used is not a
requirement but is a common pattern.

## Toolchain actions

This document doesn't cover `action_config`s, but the legacy behavior
applies to them as well, and the names of the action configurations are
also special.

## Legacy features

By default, unless you add the `no_legacy_features` feature to your
toolchain, you will automatically inherit defaults defined in
[`legacy_features.bzl`](../cc/private/toolchain_config/legacy_features.bzl).
It is recommended that you override all features to avoid this
potentially confusing behavior. You can read that file to see the
current defaults.

If you do not add a `no_legacy_features` feature, any features you add
with the same name as a legacy feature will override the default
behavior, but any that you omit will be added to your toolchain
implicitly.

NOTE: Not all of these features work in the default toolchain, so some
might only be relevant if you are writing your own toolchain.

### Legacy features with special names

Most legacy features are just strings with no special meaning. There are
a few exceptions to this.

#### `coverage` / `gcc_coverage_map_format` / `llvm_coverage_map_format`

Bazel / `rules_cc` automatically enables the `coverage` feature when
using `bazel coverage` or `bazel build --collect_code_coverage`. Bazel
then either enables `gcc_coverage_map_format` (default) or
`llvm_coverage_map_format` (if `--experimental_use_llvm_covmap` is set).
At this point it is up to the toolchain to pass the correct compiler /
linker flags.

#### `fully_static_link`

`fully_static_link` is not used by `rules_cc` directly but is
recommended in the `cc_binary` documentation for producing fully
statically linked binaries. If you want to support this it should be
implemented in your toolchain.

#### `per_object_debug_info`

This feature name, alongside the value of
[`--fission`](https://bazel.build/reference/command-line-reference#flag--fission)
is used to determine per-object debug info should be enabled.

#### `pic` / `supports_pic`

Bazel / `rules_cc` checks if your toolchain has an enabled feature named
`supports_pic` to determine if position independent code is supported at
all. If so it also expects an enabled feature named `pic` which actually
adds the relevant compiler flags in the correct cases (only when the
`pic` variable is enabled). You should also add another feature that
respects the `force_pic` variable, which reacts to the `--force_pic`
flag.

See also [`prefer_pic_for_opt_binaries`](#prefer_pic_for_opt_binaries)

#### Profile guided optimization features

`rules_cc` has quite a few PGO/FDO features, which are all automatically
enabled based on various [`--fdo_*`](https://bazel.build/reference/command-line-reference#flag--fdo_instrument)
flags it supports. To get the most up to date information on how all of
these fit together it's best to look at the code. The combination of all
of these features likely isn't well tested today.

The current list of features (not all of these are provided by the
legacy feature) is:

- `autofdo`
- `cs_fdo_instrument`
- `cs_fdo_optimize`
- `enable_afdo_thinlto`
- `enable_autofdo_memprof_optimize`
- `enable_fdo_memprof_optimize`
- `enable_fdo_split_functions`
- `enable_fdo_thinlto`
- `enable_fsafdo`
- `enable_xbinaryfdo_thinlto`
- `fdo_instrument`
- `fdo_optimize`
- `fdo_prefetch_hints`
- `propeller_optimize_thinlto_compile_actions`
- `propeller_optimize`
- `xbinary_fdo`
- `xbinaryfdo` (yes both of these exist)

## Other features

These features are not part of the legacy features, but might be part of
the default cc toolchains, and can potentially be enabled / disabled via
`--features` / `--host_features`.

#### `archive_param_file`

A marker feature indicating that the archiver supports reading arguments
from a `@params` file.

#### `compiler_param_file`

A marker feature indicating that bazel / `rules_cc` should pass
arguments to the compiler with a `@params` file.

#### `compile_all_modules`

A marker feature that causes all headers in the generated `modulemap`s
for [`layering_check`](#layering_check) to be written as compilable
`header` instead of `textual header`, which causes `clang` to attempt
to build a compiled module from them. This is required for actually
building modules from the generated `modulemap`s, which isn't
necessary for common `layering_check` uses.

Expected to be supported for Swift interop.

#### `copy_dynamic_libraries_to_binary`

A marker feature that causes bazel to copy dependent shared libraries to
the output directory of a `cc_binary` when linking against them. This is
commonly used on Windows.

#### `cpp_modules`

A marker feature for enabling C++20 modules. This also depends on
`--experimental_cpp_modules` being passed.

#### `dbg` / `fastbuild` / `opt`

These features are requested based on
[`--compilation_mode`](https://bazel.build/reference/command-line-reference#flag--compilation_mode)
and primarily useful for customizing other features in the toolchain.

#### `dead_strip`

This feature is requested based on
[`--objc_enable_binary_stripping`](https://bazel.build/reference/command-line-reference#flag--objc_enable_binary_stripping)
and commonly correlates with the `-dead_strip` linker flag.

#### `disable_whole_archive_for_static_lib`

Disable allowing `alwayslink = True` usage on a library.

#### `dynamic_link_test_srcs`

A marker feature that affects linking behavior of `cc_test` targets. See
the source for details.

#### `exclude_private_headers_in_module_maps`

A marker feature for excluding private headers from the generated
`modulemap`s for [`layering_check`](#layering_check). Otherwise private
headers are included with `private header`.

Expected to be supported for Swift interop.

#### `external_include_paths`

A marker feature indicating that all external bazel modules' include
paths should be passed through `-isystem` instead of `-I`. This is still
up to the toolchain to configure correctly, but this affects the
toolchain variables the include paths are passed through.

#### `force_no_whole_archive` / `legacy_whole_archive`

Deprecated marker features to disable linking shared libraries with
`--whole-archive` by default.

#### `gcc_quoting_for_param_files` / `windows_quoting_for_param_files`

Marker features to configure the quoting style of arguments in `@params`
files. If neither are enabled, no quoting is applied.

#### `generate_submodules`

A marker feature for generating submodules for each header in the
generated `modulemap`s for [`layering_check`](#layering_check).

#### `has_configured_linker_path`

A marker feature indicating that when creating an interface shared
library, the toolchain calls the default configured linker. In this case
it's up to the default linker and toolchain to correctly emit both the
standard library, and the interface library. If this is not set
`rules_cc` uses the `@bazel_tools//tools/cpp:link_dynamic_library`
helper instead.

#### `header_module_codegen` / `header_modules` / `use_header_modules`

Use `clang` modules for some cases. Read the source for details.

#### `generate_dsym_file` / `no_generate_debug_symbols`

`generate_dsym_file` is requested based on
[`--apple_generate_dsym`](https://bazel.build/reference/command-line-reference#flag--apple_generate_dsym)
and indicates that the toolchain should generate a dsym file for
debugging on Apple platforms. `no_generate_debug_symbols` is set in the opposite case.

#### `generate_linkmap`

This feature is requested based on
[`--objc_generate_linkmap`](https://bazel.build/reference/command-line-reference#flag--objc_generate_linkmap)
and commonly correlates with the `-map` linker flag.

#### `generate_pdb_file`

This feature indicates a Windows `pdb` file should be created when
linking a binary. This must be enabled by the user or the toolchain.

#### `lang_objc`

A marker feature indicating that Objective-C or Objective-C++ is being
built.

#### `layering_check`

Enable validation that a library directly depends on everything it uses.
This is implemented using `clang`'s `modulemap` features. See the
default toolchains for implementation examples. `rules_cc` does not
reference this feature directly, but the name `layering_check` is used
by users to enable this behavior, and disable it for incompatible
targets.

#### LTO features

Bazel / `rules_cc` have a man special features for LTO behavior:

- `thin_lto` top level feature that is also used by users
- `thin_lto_all_linkstatic_use_shared_nonlto_backends` read the source
- `thin_lto_linkstatic_tests_use_shared_nonlto_backends` read the source
- `no_use_lto_indexing_bitcode_file` read the source
- `use_lto_native_object_directory` read the source

#### `module_maps`

A marker feature that should always be enabled if supported indicating
that the compiler supports `modulemap` files (`clang`). This is required
for `layering_check`.

#### `module_map_home_cwd`

Whether a `modulemap` used with [`layering_check`](#layering_check)
should use its current directory as the `cwd`. This affects relative
paths in the generated `modulemap`s. This is only useful if you need to
also pass the related `clang` flags.

#### `module_map_without_extern_module`

A marker feature to disable writing `extern module` declarations in the
generated `modulemap`s for [`layering_check`](#layering_check).

Expected to be supported for Swift interop.

#### `no_dotd_file`

A marker feature for disabling `.d` file generating and parsing by
bazel. Dotd file parsing is also dependent on
[`--cc_dotd_files`](https://bazel.build/reference/command-line-reference#flag--cc_dotd_files)
and
[`--objc_use_dotd_pruning`](https://bazel.build/reference/command-line-reference#flag--objc_use_dotd_pruning)

#### `no_legacy_features`

Disable `rules_cc` automatically adding the legacy features to the
toolchain (discussed  above).

#### `no_stripping`

When enabled `rules_cc` does not strip a `cc_binary` to create the
implicit `binary.stripped`, instead it is only symlinked.

#### `only_doth_headers_in_module_maps`

A marker feature for only including `.h` files in the generated
`modulemap`s for [`layering_check`](#layering_check). Otherwise public
headers with any extension are included.

Expected to be supported for Swift interop.

#### `parse_headers`

This feature is used alongside
[`--process_headers_in_dependencies`](https://bazel.build/reference/command-line-reference#flag--process_headers_in_dependencies)
to run a separate action that validates header files are valid on their
own. This feature is special to `rules_cc` but is also used by users to
enable this behavior, and disable it for incompatible targets.

See also [`layering_check`](#layering_check)

#### `parse_showincludes`

A marker feature for enabling parsing of the output of `/showIncludes`
to generate `.d` for parsing by bazel. Dotd file parsing is also
dependent on
[`--cc_dotd_files`](https://bazel.build/reference/command-line-reference#flag--cc_dotd_files)
and
[`--objc_use_dotd_pruning`](https://bazel.build/reference/command-line-reference#flag--objc_use_dotd_pruning)

#### `prefer_pic_for_opt_binaries`

A marker feature to automatically enable position independent code when
using `--compilation_mode=opt`.

#### `no_copts_tokenization`

A marker feature to disable shell tokenization of `copts` in the toolchain.
This can be used by users to make sure special characters that are
expected in `defines` / `copts` are not processed. This is required in
some cases when you have quoted arguments.

#### `sanitize_pwd`

A marker feature indicating the toolchain has sanitized the `PWD` from
the outputs. Otherwise `rules_cc` will set `PWD=/proc/self/cwd` (unless
on macOS) when linking a binary. This is commonly used when
`-fdebug-prefix-map` is supported by the compiler.

#### `set_soname`

A marker feature that causes interface libraries to respect the `soname`
they have. Otherwise `-soname` is passed when creating interface libraries.

#### `serialized_diagnostics_file`

A marker feature for enabling generating a serialized diagnostics file
from the compiler. Commonly used with the `--serialize-diagonostics`
`clang` flag.

#### `shorten_virtual_includes`

A marker feature that causes virtual include paths generated by
`strip_include_prefix` and friends to use a shorter path. This is useful
on Windows to avoid long path issues.

#### `static_link_cpp_runtimes`

A marker feature used by `rules_cc` to determine if the toolchain
supports statically

#### `supports_dynamic_linker`

A marker feature that indicates 2 things:

1. That `cc_library` targets can create "nodeps" shared libraries for
   use with
   [`--dynamic_mode`](https://bazel.build/reference/command-line-reference#flag--dynamic_mode).
   This requires shared libraries can be created without seeing their
   dependencies' symbols, which can lead to runtime crashes, but can
   reduce large static links for small changes.
2. Whether a `cc_binary` prefers linking static over shared libraries
   when both are available for a target.

#### `supports_interface_shared_libraries`

A marker feature indicating that the toolchain supports creating
interface libraries for a shared libraries. This can be used to reduce
input tree size of downstream linking actions.

#### `supports_start_end_lib`

Whether the toolchain supports using the `--start-lib` / `--end-lib`
linker flags. This is required for use with `LTO`.

#### `symbol_check`

A feature automatically requested by `cc_static_library` that enables
the toolchain to enable optional validation around the symbols in the
produced static library.

#### `system_include_paths`

A marker feature indicating that include paths from the `includes`
attribute of a target should be passed with `-isystem` instead of `-I`.
This is still up to the toolchain to configure correctly, but this
affects the toolchain variables the include paths are passed through.
This is expected to be set by users when necessary (hopefully rarely).

#### `targets_windows`

This is used by `rules_cc` to change the behavior in various places only
when building for Windows. If your toolchain targets Windows this should
be enabled.

#### `treat_warnings_as_errors`

A user-enabled feature requesting that warnings are treated as errors.
This is not special to `rules_cc`. This is commonly used with the
`-Werror` compiler flag.

#### `validates_layering_check_in_textual_hdrs`

Whether `layering_check` should also apply to the `textual_hdrs`
attribute of targets.

See also [`layering_check`](#layering_check)

#### `windows_export_all_symbols` / `no_windows_export_all_symbols`

Marker features to configure whether a `.def` should be created. The
negating feature wins if both are enabled.

#### `warn_backrefs_defined`

A marker feature indicating `-Wl,--warn-backrefs-exclude` should be
passed when linking static libraries downstream of a `cc_import`
