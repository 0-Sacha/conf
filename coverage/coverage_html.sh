#!/bin/bash

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <compile_commands_rule>"
    exit 1
fi

BAZEL_RULE=$1
shift

bazelisk coverage $BAZEL_RULE --combined_report=lcov $*
genhtml --branch-coverage --output .coverage/html "$(bazelisk info output_path)/_coverage/_coverage_report.dat"
