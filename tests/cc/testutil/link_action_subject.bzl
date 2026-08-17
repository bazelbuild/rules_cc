"""Subject for asserting on Link Actions."""

load("//tests/cc/testutil:cc_binary_target_subject.bzl", "cc_binary_target_subject")

def _link_action_subject_from_target(env, target):
    return cc_binary_target_subject.from_target(env, target).action_generating(
        "{package}/{name}{binary_extension}",
    )

link_action_subject = struct(
    from_target = _link_action_subject_from_target,
)
