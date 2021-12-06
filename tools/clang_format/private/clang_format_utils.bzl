"""Helpers for the `clang-format` rules"""

BuildSettingInfo = provider(
    doc = "A singleton provider that contains the raw value of a build setting",
    fields = {
        "value": "The value of the build setting in the current configuration. " +
                 "This value may come from the command line or an upstream transition, " +
                 "or else it will be the build setting's default.",
    },
)

def _impl(ctx):
    if hasattr(ctx.attr, "value"):
        value = ctx.attr.value
    else:
        value = ctx.build_setting_value
    return BuildSettingInfo(value = value)

bool_setting = rule(
    implementation = _impl,
    attrs = {
        "value": attr.bool(
            doc = "The setting's value",
            default = False,
        ),
    },
    doc = "A bool-typed build setting that cannot be set on the command line",
)

string_list_flag = rule(
    implementation = _impl,
    build_setting = config.string_list(flag = True),
    doc = "A string list-typed build setting that can be set on the command line",
)

def _build_setting_file_impl(ctx):
    output = ctx.actions.declare_file(ctx.label.name)

    value = ctx.attr.setting[BuildSettingInfo].value
    content = None
    if type(value) == "str":
        content = value
    elif type(value) == "list":
        content = "\n".join(value)
    else:
        fail("Unexpected type: {} for {}".format(
            type(value),
            ctx.attr.setting.label,
        ))

    ctx.actions.write(
        output = output,
        content = content,
    )

    return DefaultInfo(
        files = depset([output]),
        runfiles = ctx.runfiles(files = [output]),
    )

build_setting_file = rule(
    implementation = _build_setting_file_impl,
    doc = "A rule for writing the values of build settings to file",
    attrs = {
        "setting": attr.label(
            doc = "A build setting target to write to disk",
            providers = [BuildSettingInfo],
            mandatory = True,
        ),
    },
)

_HEADER_TEMPLATE = """\
#ifndef _CLANG_FORMAT_WORKSPACE_H_INCLUDE_
#define _CLANG_FORMAT_WORKSPACE_H_INCLUDE_
namespace clang_format_utils {{
    static const char* WORKSPACE_NAME = "{}";
}}
#endif  // _CLANG_FORMAT_WORKSPACE_H_INCLUDE_
"""

def _workspace_header_impl(ctx):
    output = ctx.actions.declare_file(ctx.label.name)

    ctx.actions.write(
        output = output,
        content = _HEADER_TEMPLATE.format(
            ctx.workspace_name,
        ),
    )

    return DefaultInfo(
        files = depset([output]),
    )

workspace_header = rule(
    implementation = _workspace_header_impl,
    doc = "A rule for generating a header file with the workspace name embedded in it",
)
