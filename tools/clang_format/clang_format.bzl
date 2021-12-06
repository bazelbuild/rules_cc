"""## Overview
Rules related to [clang-format][cf]

### Setup

The first thing that needs to be setup is the toolchain. To do so, add something like the following snippet
to set one up:

```python
load("@rules_cc//tools/clang_format:clang_format.bzl", "clang_format_toolchain")

clang_format_toolchain(
    name = "clang_format_toolchain_impl",
    # This path matches the common linux path though it may vary from system to system.
    # `clang_format_path` is the easiest way to setup the toolchain though the `clang_format`
    # label attribute is going to be the most consistent and is thus recommended where possible.
    clang_format_path = "/usr/bin/clang-format",
)

toolchain(
    name = "clang_format_toolchain",
    toolchain = "clang_format_toolchain_impl",
    toolchain_type = "@rules_cc//tools/clang_format:toolchain_type",
)
```

With a toolchain setup, formatting your C/C++ targets source code requires no additional setup outside of 
loading `rules_cc` in your workspace. Simply run `bazel run @rules_cc//tools/clang_format` to format source code.

In addition to this formatter, a check can be added to your build phase using the [clang_format_aspect](#clang_format_aspect)
aspect. Simply add the following to a `.bazelrc` file to enable this check.

```text
build --aspects=@rules_cc//tools/clang_format:clang_format.bzl%clang_format_aspect
build --output_groups=+clang_format_checks
```

It's recommended to only enable this aspect in your CI environment so formatting issues do not
impact user's ability to rapidly iterate on changes.

The `clang_format_aspect` also uses a `--@rules_cc//tools/clang_format:clang_format_config` setting which determines
the [configuration file][so] used by the formatter (`@rules_cc//tools/clang_format`) and the aspect
(`clang_format_aspect`). This flag can be added to your `.bazelrc` file to ensure a consistent config file is used
whenever `clang-format` is run:

```text
build --@rules_cc//tools/clang_format:clang_format_config=//:.clang-format
```
[cf]: https://clang.llvm.org/docs/ClangFormat.html
[so]: https://clang.llvm.org/docs/ClangFormatStyleOptions.html
"""

load("@rules_cc//cc:defs.bzl", "cc_binary")
load("//tools/clang_format/private:clang_format_utils.bzl", "BuildSettingInfo")

_WINDOWS_WRAPPER = """\
@ECHO OFF
{} %*
"""

_UNIX_WRAPPER = """\
#!/usr/bin/env bash
set -euo pipefail
eval exec "{}" "$@"
"""

def _create_wrapper(ctx, path, name, is_windows):
    """Create a wrapper script for executing an executable at a provided path

    Args:
        ctx (ctx): The rule's context object
        path (str): The path of the tool to execute
        name (str): The name of the wrapper script (minus a `.sh` or `.bat` extension)
        is_windows (bool): Whether or not the execution platform is Windows.


    Returns:
        path: The generated wrapper script
    """

    if is_windows:
        extension = ".bat"
        template = _WINDOWS_WRAPPER
    else:
        extension = ".sh"
        template = _UNIX_WRAPPER

    wrapper = ctx.actions.declare_file(name + extension)
    ctx.actions.write(
        wrapper,
        template.format(path),
        is_executable = True,
    )

    return wrapper

def _clang_format_toolchain_impl(ctx):
    is_windows = ctx.attr._is_windows[BuildSettingInfo].value

    if ctx.attr.clang_format:
        clang_format = ctx.executable.clang_format
    elif ctx.attr.clang_format_path:
        name = "{}.clang-format".format(ctx.label.name)
        clang_format = _create_wrapper(ctx, ctx.attr.clang_format_path, name, is_windows)
    else:
        fail("No clang-format binary provided. Please either set `clang_format` or `clang_format_path`")

    diff_tool = ctx.executable.diff_tool
    if not diff_tool and ctx.attr.diff_tool_path:
        name = "{}.diff".format(ctx.label.name)
        diff_tool = _create_wrapper(ctx, ctx.attr.diff_tool_path, name, is_windows)

    make_variables = {
        "CLANG_FORMAT": clang_format.path,
    }

    if diff_tool:
        make_variables.update({"CLANG_FORMAT_DIFF_TOOL": diff_tool.path})

    return [platform_common.ToolchainInfo(
        clang_format = clang_format,
        diff_tool = diff_tool,
        make_variables = platform_common.TemplateVariableInfo(make_variables),
    )]

clang_format_toolchain = rule(
    doc = "A toolchain providing binaries required for `clang-format` rules.",
    implementation = _clang_format_toolchain_impl,
    attrs = {
        "clang_format": attr.label(
            doc = "A `clang-format` binary",
            allow_files = True,
            cfg = "exec",
            executable = True,
        ),
        "clang_format_path": attr.string(
            doc = (
                "Either an absolute path to a `clang-format` binary or the " +
                "name of a binary located in the `PATH` environment variable"
            ),
        ),
        "diff_tool": attr.label(
            doc = (
                "A diff binary used to produce diffs. Thus must conform to " +
                "the `{diff_tool} {src1} {src2}` api"
            ),
            allow_files = True,
            cfg = "exec",
            executable = True,
        ),
        "diff_tool_path": attr.string(
            doc = (
                "Either an absolute path to a diff tool binary or the name " +
                "of a binary located in the `PATH` environment variable. " +
                "Must conform to the `{diff_tool} {src1} {src2}` api"
            ),
        ),
        "_is_windows": attr.label(
            doc = "A `bool_setting` identifying whether or not the exec platform is windows",
            cfg = "exec",
            default = Label("//tools/clang_format/private:is_windows"),
        ),
    },
)

def _current_clang_format_toolchain_impl(ctx):
    toolchain = ctx.toolchains[str(Label("//tools/clang_format:toolchain_type"))]

    return [
        toolchain,
        toolchain.make_variables,
        DefaultInfo(
            files = depset([
                toolchain.clang_format,
            ]),
            runfiles = ctx.runfiles(files = [toolchain.clang_format]),
        ),
    ]

current_clang_format_toolchain = rule(
    doc = "A rule for exposing the current registered `clang_format_toolchain`.",
    implementation = _current_clang_format_toolchain_impl,
    toolchains = [
        str(Label("//tools/clang_format:toolchain_type")),
    ],
    incompatible_use_toolchain_transition = True,
)

def _find_formattable_srcs(target, aspect_ctx):
    """Parse a target for clang-format formattable sources.

    Args:
        target (Target): The target the aspect is running on.
        aspect_ctx (ctx, optional): The aspect's context object.

    Returns:
        list: A list of formattable sources (`File`).
    """
    if CcInfo not in target:
        return []

    # Ignore external targets
    if target.label.workspace_root.startswith("external"):
        return []

    # Targets tagged to indicate "don't format" will not be formatted
    if aspect_ctx:
        for tag in ["noformat", "no-format", "no-clang-format"]:
            if tag in aspect_ctx.rule.attr.tags:
                return []

    # Collect all source files
    srcs = []
    for attr in aspect_ctx.attr._source_attrs[BuildSettingInfo].value:
        srcs.extend(getattr(aspect_ctx.rule.files, attr, list()))

    # Filter out any duplicate or generated files
    srcs = [src for src in depset(srcs).to_list() if src.is_source]

    # Filter out any sources that don't match the correct extension
    srcs = [src for src in srcs if src.extension in aspect_ctx.attr._extensions[BuildSettingInfo].value]

    return sorted(srcs)

def _perform_check(ctx, target, srcs):
    """Run `clang-format` and errors out if a defect is detected

    Args:
        ctx (ctx): The rule's or aspect's context object
        target (target): The aspect target
        srcs (list): A list of File objects

    Returns:
        path: An indicator that `clang-format` ran successfully.
    """
    toolchain = ctx.toolchains[Label("//tools/clang_format:toolchain_type")]

    marker = ctx.actions.declare_file(ctx.label.name + ".clang_format.ok")
    config = ctx.file._config

    tools = [toolchain.clang_format]
    args = ctx.actions.args()
    args.add("--touch-file", marker)

    args.add("--config-file", config)
    for src in srcs:
        args.add("--source-file", src)

    if toolchain.diff_tool:
        tools.append(toolchain.diff_tool)
        args.add("--diff-tool-file", toolchain.diff_tool)
        args.add("--")
        args.add(toolchain.clang_format)
        args.add("-style=file")
        args.add("-i")
    else:
        args.add("--")
        args.add(toolchain.clang_format)
        args.add("-style=file")
        args.add("-Werror")
        args.add("-dry-run")

    ctx.actions.run(
        executable = ctx.executable._process_wrapper,
        inputs = srcs + [config],
        outputs = [marker],
        tools = tools,
        arguments = [args],
        mnemonic = "ClangFormat",
        progress_message = "Running clang-format on '{}'".format(
            target.label,
        ),
        use_default_shell_env = True,
    )

    return marker

def _clang_format_aspect_impl(target, ctx):
    srcs = _find_formattable_srcs(target, ctx)

    # If there are no formattable sources, do nothing.
    if not srcs:
        return []

    marker = _perform_check(ctx, target, srcs)

    return [
        OutputGroupInfo(
            clang_format_checks = depset([marker]),
        ),
    ]

clang_format_aspect = aspect(
    implementation = _clang_format_aspect_impl,
    doc = """\
This aspect is used to gather information about a target for use with [clang-format] and perform a formatting check

Output Groups:
- `clang_format_checks`: Executes `clang-format` checks on the specified target.

The build setting `@rules_cc//tools/clang_format:clang_format_config` is used to control the `clang-format` 
[configuration settings][cs] used at runtime.

This aspect is executed on any target which provides the [CcInfo][ci] provider. However users may tag a target with
`noformat`, `no-format`, or `no-clang-format` to have it skipped. Additionally, there are two flags which can be used
to futher control how source files are detected by this aspect:
- `@rules_cc//tools/clang_format:clang_format_extensions`: An allow list of source file extensions to be formatted
- `@rules_cc//tools/clang_format:clang_format_source_attrs`: Attributes on rules which provide [CcInfo][ci].

Generated source files are also ignored by this aspect.

[cf]: https://clang.llvm.org/docs/ClangFormat.html
[cs]: https://clang.llvm.org/docs/ClangFormatStyleOptions.html
[ci]: https://docs.bazel.build/versions/main/skylark/lib/CcInfo.html
""",
    attrs = {
        "_config": attr.label(
            doc = "The `.clang-format` file used for formatting",
            allow_single_file = True,
            default = Label("//tools/clang_format:clang_format_config"),
        ),
        "_extensions": attr.label(
            doc = (
                "A list of file extensions to formattable sources. This " +
                "flag enables accommodations for other rules which consume " +
                "C/C++ source files."
            ),
            default = Label("//tools/clang_format:clang_format_extensions"),
        ),
        "_process_wrapper": attr.label(
            doc = "A process wrapper for running clang-format on all platforms",
            cfg = "exec",
            executable = True,
            default = Label("//tools/clang_format/private:clang_format_process_wrapper"),
        ),
        "_source_attrs": attr.label(
            doc = (
                "A list of attributes on the target that contain " +
                "formattable sources. These attributes must satisfy the " +
                "`files` api (meaning `allow_files = True` is set). This " +
                "flag enables accommodations for other rules which consume " +
                "C/C++ source files."
            ),
            default = Label("//tools/clang_format:clang_format_source_attrs"),
        ),
    },
    incompatible_use_toolchain_transition = True,
    fragments = ["cpp"],
    host_fragments = ["cpp"],
    toolchains = [
        str(Label("//tools/clang_format:toolchain_type")),
    ],
)

def clang_format(
        name,
        config = Label("//tools/clang_format:clang_format_config"),
        types = "^cc_",
        **kwargs):
    """A rule for running `clang-format` on all formattable sources being tracked by Bazel

    Args:
        name (str): The name of the generated target
        config (Label, optional): The `.clang-format` file used for formatting.
        types (str, optional): The condition value to pass to `bazel query 'kind({types}, //...:all)'`.
        **kwargs (dict): Additional keyword arguments to pass to the underlying `cc_binary`.
    """

    current_toolchain = Label("//tools/clang_format:current_clang_format_toolchain")
    extensions_manifest = Label("//tools/clang_format/private:clang_format_extensions_file")

    args = [
        "--clang_format",
        "$(rootpath {})".format(current_toolchain),
        "--config",
        "$(rootpath {})".format(config),
        "--extensions_manifest",
        "$(rootpath {})".format(extensions_manifest),
        "--types",
        types,
        "--",
    ] + kwargs.pop("args", [])

    cc_binary(
        name = name,
        srcs = [
            Label("//tools/clang_format/private:clang_format_runner.cc"),
        ],
        args = args,
        data = [
            config,
            current_toolchain,
            extensions_manifest,
        ],
        deps = [
            Label("@bazel_tools//tools/cpp/runfiles"),
            Label("//tools/clang_format/private:clang_format_utils"),
        ],
        **kwargs
    )
