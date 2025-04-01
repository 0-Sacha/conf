#!/bin/bash

usage() {
    echo "Usage: $0 [--config <path>] [--mode <dry|exec>]"
    echo "  --config .clang-format"
    echo "  --mode <dry|exec> : 'dry' for checking formatting, 'exec' to format files (default: dry)"
    exit 1
}

version=$(clang-format --version 2>/dev/null | grep -oE '[0-9]+([0-9]+)*' | cut -d. -f1 | head -n 1)
if [[ -z "$version" ]]; then
  echo "clang-format is not installed or not found in PATH."
  exit 1
fi

if [[ "$version" -lt 18 ]]; then
  echo "clang-format version is $version; EXPECTED higher or equal than 18"
  exit 1
fi

CLANG_FORMAT_CONFIG="./conf/linter/RustLike/.clang-format"
FILES_LIST_PARSE=(-name "*.c" -o -name "*.cc" -o -name "*.cpp" -o -name "*.cxx" -o -name "*.h" -o -name "*.hh" -o -name "*.hpp" -o -name "*.hxx")
DEFAULT_SEARCH_LIST=(src tests)
SEARCH_LIST=()
SILENT="off"
APPLY="off"
while [[ $# -gt 0 ]]; do
    case $1 in
        --config|-c)
            CLANG_FORMAT_CONFIG="$2"
            shift 2
            ;;
        --checker)
            CLANG_FORMAT_CONFIG="./conf/checker/.clang-format"
            shift
            ;;
        --apply)
            APPLY="on"
            shift
            ;;
        --silent)
            SILENT="on"
            shift
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

if [[ ! -f "$CLANG_FORMAT_CONFIG" ]]; then
    echo "Error: Configuration file '$CLANG_FORMAT_CONFIG' does not exist."
    exit 1
fi

# Find files
FILES=$(find ${SEARCH_LIST[@]} -type f \( ${FILES_LIST_PARSE[@]} \))
if [[ -z "$FILES" ]]; then
    echo "No source files found in '$SEARCH_LIST'"
    exit 0
fi

FILES_ARRAY=($FILES)
TOTAL_FILES_SIZES="${#FILES_ARRAY[@]}"
CURRENT_FILE=1

# Run clang-format
ALL_PASSED=true
for FILE in $FILES; do
    if [[ "$SILENT" == "off" ]]; then
        echo "Analyzing file '$FILE' [$CURRENT_FILE/$TOTAL_FILES_SIZES]"
        CURRENT_FILE=$((CURRENT_FILE+1))
    fi

    if [[ "$APPLY" == "off" ]]; then
        clang-format --style=file:$CLANG_FORMAT_CONFIG --dry-run --Werror "$FILE" || ALL_PASSED=false
    else
        clang-format --style=file:$CLANG_FORMAT_CONFIG -i "$FILE"
    fi
done

# Exit with appropriate status
if [[ "$ALL_PASSED" == false ]]; then
    echo "Formatting issues detected."
    exit 1
fi

echo "All files processed successfully !"
exit 0
