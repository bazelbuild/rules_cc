"""Indirection to avoid breaking on Bazel 6"""

visibility("//cc/...")

# TODO(https://github.com/bazelbuild/bazel/issues/32343): Annotate **kwargs
# when Bazel can derive them from the wrapped starlark_doc_extract rule.
def starlark_doc_extract_helper(**kwargs):
    # type: (**Unpack[KeywordArgs[native.starlark_doc_extract]]) -> None
    """Creates a starlark_doc_extract target if the native rule is available

    Args:
        **kwargs: (dict) args for starlark_doc_extract
    """
    if hasattr(native, "starlark_doc_extract"):
        native.starlark_doc_extract(**kwargs)
