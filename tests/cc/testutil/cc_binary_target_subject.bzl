"""Tweaked TargetSubject for asserting on a cc_binary target.

Adds a `binary_extension` to the meta info that can be used in format strings that then
match both Windows and non-Windows targets.

Offers the same interface as TargetSubject, in fact it is just a TargetSubject, with additional
meta info.

Example use:

cc_binary_target_subject.from_target(env, target).executable().short_path_equals(
    "{package}/{name}{binary_extension}"
)
"""

load("@rules_testing//lib:truth.bzl", "subjects")

def _cc_binary_target_subject_from_target(env, target):
    helper_target_subject = env.expect.that_target(target)
    binary_extension = ""
    meta = helper_target_subject.meta.derive(
        expr = "cc_binary_target({})".format(target.label),
        details = ["cc_binary_target: {}".format(target.label)],
        format_str_kwargs = {"binary_extension": binary_extension},
    )
    return subjects.target(target, meta)

cc_binary_target_subject = struct(
    from_target = _cc_binary_target_subject_from_target,
)
