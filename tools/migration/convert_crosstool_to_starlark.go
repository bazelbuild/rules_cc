/*
The convert_crosstool_to_starlark script takes in a CROSSTOOL file and
generates a Starlark rule.

See https://github.com/bazelbuild/bazel/issues/5380

Example usage:
bazel run \
@rules_cc//tools/migration:convert_crosstool_to_starlark -- \
--crosstool=/path/to/CROSSTOOL \
--output_location=/path/to/cc_config.bzl
*/
package main

import (
	"flag"
	"fmt"
	"io/ioutil"
	"os"

	"log"
	"github.com/golang/protobuf/proto"
	crosstoolpb "third_party/com/github/bazelbuild/bazel/src/main/protobuf/crosstool_config_go_proto"

	"tools/migration/crosstooltostarlarklib"
)

var (
	crosstoolLocation = flag.String(
		"crosstool", "", "Location of the CROSSTOOL file")
	outputLocation = flag.String(
		"output_location", "", "Location of the output .bzl file")
)

func main() {

	if *crosstoolLocation == "" {
		log.Fatalf("Missing mandatory argument 'crosstool'")
	}
	if *outputLocation == "" {
		log.Fatalf("Missing mandatory argument 'output_location'")
	}

	in, err := ioutil.ReadFile(*crosstoolLocation)
	if err != nil {
		log.Fatalf("Error reading CROSSTOOL file:", err)
	}
	crosstool := &crosstoolpb.CrosstoolRelease{}
	if err := proto.UnmarshalText(string(in), crosstool); err != nil {
		log.Fatalf("Failed to parse CROSSTOOL:", err)
	}

	file, err := os.Create(*outputLocation)
	if err != nil {
		log.Fatalf("Error creating output file:", err)
	}
	defer file.Close()

	rule, err := crosstooltostarlarklib.Transform(crosstool)
	if err != nil {
		log.Fatalf("Error converting CROSSTOOL to a Starlark rule:", err)
	}

	if _, err := file.WriteString(rule); err != nil {
		log.Fatalf("Error converting CROSSTOOL to a Starlark rule:", err)
	}
	fmt.Println("Success!")
}
