#!/bin/bash

usage() {
    echo "Usage: $0 <compile_commands_rule> <server_product_url>"
    exit 1
}

if [ "$#" -lt 2 ]; then
    usage
fi

BAZEL_RULE=$1
CODECHEKER_SERVER_PRODUCT_URL=$2
CODECHEKER_SERVER_STORE_NAME=""
GIT_BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)

shift 2

CHECKERS_EXTRA=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --store-name|-n)
            CODECHEKER_SERVER_STORE_NAME="/$2"
            shift 2
            ;;
        --branch-name)
            GIT_BRANCH_NAME="$2"
            shift 2
            ;;
        --disable|-d)
            CHECKERS_EXTRA="$CHECKERS_EXTRA --disable $2"
            shift 2
            ;;
        --enable|-e)
            CHECKERS_EXTRA="$CHECKERS_EXTRA --enable $2"
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

bazelisk run $BAZEL_RULE

CodeChecker analyze compile_commands.json -j32 -o .checker/reports/latest \
    --enable-all \
    \
    --disable gcc \
    --disable cppcheck \
    \
    --enable alpha \
    --enable llvm \
    --enable abseil \
    --enable zircon \
    --enable hicpp \
    --enable fuchsia \
    \
    --skip ./conf/checker/skipfiles \
    \
    --disable misc-no-recursion \
    --disable llvm-header-guard \
    --disable modernize-use-trailing-return-type \
    --disable llvm-include-order \
    --disable llvm-namespace-comment \
    --disable fuchsia-default-arguments-calls \
    --disable fuchsia-default-arguments-declarations \
    \
    --disable hicpp-uppercase-literal-suffix \
    --disable clang-diagnostic-c++98-compat \
    --disable readability-uppercase-literal-suffix \
    --disable readability-identifier-length \
    --disable readability-redundant-access-specifiers \
    --disable readability-simplify-boolean-expr \
    --disable bugprone-easily-swappable-parameters \
    \
    \
    --disable altera-struct-pack-align \
    --disable altera-unroll-loops \
    \
    --saargs ./conf/checker/extra_sa_compile_flags.txt \
    --disable clang-diagnostic-padded \
    \
    $CHECKERS_EXTRA

# https://codechecker.readthedocs.io/en/latest/usage/#step-8-integrate-codechecker-into-your-ci-loop
CodeChecker store .checker/reports/latest \
    -n "$BAZEL_RULE -- $GIT_BRANCH_NAME$CODECHEKER_SERVER_STORE_NAME" \
    --url $CODECHEKER_SERVER_PRODUCT_URL \
    --trim-path-prefix $(pwd) \
    # --tag \

CodeChecker parse .checker/reports/latest --export json > .checker/report-latest.json

severity_hist=$(jq ".reports.[].severity" .checker/report-latest.json | sort | uniq -c)
severity_count=$(echo "$severity_hist" | grep -E 'LOW|MEDIUM|HIGH|CRITICAL' | wc -l)
if (( severity_count > 0 )); then
    exit 1
fi
