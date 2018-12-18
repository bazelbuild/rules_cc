"""Script migrating legacy CROSSTOOL fields into features.

This script migrates the CROSSTOOL to use only the features to describe C++
command lines. It is intended to be added as a last step of CROSSTOOL generation
pipeline. Since it doesn't retain comments, we assume CROSSTOOL owners will want
to migrate their pipeline manually.
"""

# Tracking issue: https://github.com/bazelbuild/bazel/issues/5187
#
# Since C++ rules team is working on migrating CROSSTOOL from text proto into
# Starlark, we advise CROSSTOOL owners to wait for the CROSSTOOL -> Starlark
# migrator before they invest too much time into fixing their pipeline. Tracking
# issue for the Starlark effort is
# https://github.com/bazelbuild/bazel/issues/5380.

from absl import app
from absl import flags
from google.protobuf import text_format
from third_party.com.github.bazelbuild.bazel.src.main.protobuf import crosstool_config_pb2
from tools.migration.legacy_fields_migration_lib import migrate_legacy_fields

flags.DEFINE_string("input", None, "Input CROSSTOOL file to be migrated")
flags.DEFINE_string("output", None,
                    "Output path where to write migrated CROSSTOOL.")


def main(unused_argv):
  crosstool = crosstool_config_pb2.CrosstoolRelease()

  input_filename = flags.FLAGS.input
  output_filename = flags.FLAGS.output

  if not input_filename:
    raise app.UsageError("ERROR input unspecified")
  if not output_filename:
    raise app.UsageError("ERROR output unspecified")

  f = open(input_filename, "r")
  input_text = f.read()
  text_format.Merge(input_text, crosstool)
  f.close()

  output_text = migrate_legacy_fields(crosstool)

  f = open(output_filename, "w")
  output_text = text_format.MessageToString(crosstool)
  f.write(output_text)
  f.close()


if __name__ == "__main__":
  app.run(main)
