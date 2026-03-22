"""Helper rule for providing TemplateVariableInfo in tests."""

def _make_var_provider_impl(ctx):
    return [platform_common.TemplateVariableInfo(ctx.attr.variables)]

make_var_provider = rule(
    implementation = _make_var_provider_impl,
    attrs = {
        "variables": attr.string_dict(),
    },
)
