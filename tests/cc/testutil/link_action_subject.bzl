"""Subject for asserting on Link Actions."""

load("@rules_testing//lib:truth.bzl", "subjects")
load("//tests/cc/testutil:cc_binary_target_subject.bzl", "cc_binary_target_subject")

def _link_action_subject_new(actual, meta):
    return struct(
        actual = actual,
        meta = meta,
        inputs = lambda: subjects.collection([f.short_path for f in actual.inputs.to_list()], meta = meta.derive("inputs")),
        outputs = lambda: subjects.collection([f.short_path for f in actual.outputs.to_list()], meta = meta.derive("outputs")),
        argv = lambda: subjects.collection(actual.argv, meta = meta.derive("argv")),
        env = lambda: subjects.dict(actual.env, meta = meta.derive("env")),
    )

def _link_action_subject_from_target(env, target):
    action_subject = cc_binary_target_subject.from_target(env, target).action_generating(
        "{package}/{name}{binary_extension}",
    )
    return _link_action_subject_new(action_subject.actual, action_subject.meta)

link_action_subject = struct(
    new = _link_action_subject_new,
    from_target = _link_action_subject_from_target,
)
