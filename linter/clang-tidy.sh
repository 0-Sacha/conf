#!/bin/bash

usage() {
    echo "Usage: $0 [--config <path>] [--json <path>]"
    echo "  --config .clang-tidy"
    echo "  --json compile_commands.json"
    exit 1
}

version=$(clang-tidy --version 2>/dev/null | grep -oE '[0-9]+([0-9]+)*' | cut -d. -f1 | head -n 1)
if [[ -z "$version" ]]; then
  echo "clang-tidy is not installed or not found in PATH."
  exit 1
fi

if [[ "$version" -lt 18 ]]; then
  echo "clang-tidy version is $version; EXPECTED higher or equal than 18"
  exit 1
fi

BAZEL_CMD_LINE=$1
shift

COMPILE_COMMANDS="compile_commands.json"
CLANG_TIDY_CONFIG="./conf/linter/RustLike/.clang-tidy"
DEFAULT_SEARCH_LIST=(src tests)
SEARCH_LIST=()
FILES_LIST_PARSE=(-name "*.c" -o -name "*.cc" -o -name "*.cpp" -o -name "*.cxx")
while [[ $# -gt 0 ]]; do
    case $1 in
        --json|-p)
            COMPILE_COMMANDS="$2"
            shift 2
            ;;
        --enable-headers)
            FILES_LIST_PARSE=(-name "*.c" -o -name "*.cc" -o -name "*.cpp" -o -name "*.cxx" -o -name "*.h" -o -name "*.hh" -o -name "*.hpp" -o -name "*.hxx")
            shift
            ;;
        --config|-c)
            CLANG_TIDY_CONFIG="$2"
            shift 2
            ;;
        *)
            SEARCH_LIST+=($1)
            shift
            ;;
    esac
done

if [ ${#SEARCH_LIST[@]} -eq 0 ]; then
    SEARCH_LIST=("${DEFAULT_SEARCH_LIST[@]}")
    echo "search list is empty, using the default list: ${SEARCH_LIST[@]}"
fi

if [[ ! -f "$CLANG_TIDY_CONFIG" ]]; then
    echo "Error: Configuration file '$CLANG_TIDY_CONFIG' does not exist."
    exit 1
fi

bazelisk run $BAZEL_CMD_LINE

# Find files
FILES=$(find ${SEARCH_LIST[@]} -type f \( ${FILES_LIST_PARSE[@]} \))
if [[ -z "$FILES" ]]; then
    echo "No source files found in '$SEARCH_LIST'"
    exit 0
fi

# Run clang-tidy
ALL_PASSED=true
for FILE in $FILES; do
    clang-tidy --config-file=$CLANG_TIDY_CONFIG -p compile_commands.json "$FILE" || ALL_PASSED=false
done

# Exit with appropriate status
if [[ "$ALL_PASSED" == false ]]; then
    echo "Tidy issues detected."
    exit 1
fi

echo "All files processed successfully !"
exit 0
