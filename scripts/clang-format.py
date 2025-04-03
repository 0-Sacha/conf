#!/bin/python3

import argparse
import subprocess
import os
import sys
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

# https://gist.github.com/JBlond/2fea43a3049b38287e5e9cefc87b2124
def red(text):
    return f"\033[31m{text}\033[0m"
def green(text):
    return f"\033[32m{text}\033[0m"
def grayed(text):
    return f"\033[90m{text}\033[0m"

def get_clang_format_version():
    try:
        output = subprocess.check_output(["clang-format", "--version"], stderr=subprocess.DEVNULL, text=True)
        version = int(output.split()[3].split('.')[0])
        return version
    except (subprocess.CalledProcessError, FileNotFoundError, IndexError, ValueError):
        print(red("clang-format is not installed or not found in PATH."))
        sys.exit(1)

def parse_arguments():
    parser = argparse.ArgumentParser(description="Run clang-format on C/C++ files.")
    parser.add_argument("-c", "--config", default="./conf/linter/RustLike/.clang-format", help="Path to .clang-tidy config")
    parser.add_argument("--apply", action="store_true", help="Apply fixes with clang-tidy")
    parser.add_argument("--silent", action="store_true", help="Suppress output messages")
    parser.add_argument("-f", "--folder", action="append", help="Directories to search for source files (can be specified multiple times) (Default is [\"src\", \"tests\"])")
    parser.add_argument("-j", "--jobs", type=int, default=os.cpu_count(), help="max parallels jobs")
    parser.add_argument("--clang-format-bin", default="clang-format", help="clang-format binary")
    return parser.parse_args()

def find_source_files(search_list):
    extensions = [".c", ".cc", ".cpp", ".cxx"] + [".h", ".hh", ".hpp", ".hxx"]
    files = []
    for directory in search_list:
        for ext in extensions:
            files.extend(Path(directory).rglob(f"*{ext}"))
    return files

def run_clang_format(file, config, apply, silent, clang_format_bin, index, total):  
    cmd = [clang_format_bin, f"--style=file:{config}", str(file)]
    if apply:
        cmd.append("-i")
    else:
        cmd += [ "--dry-run", "--Werror" ]

    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode != 0:
        print(red(f"Analyzing file '{file}' [{index}/{total}]"))
        print(result.stderr, file=sys.stderr)
        print(result.stdout, file=sys.stdout)
        return False
    elif not silent:
        print(grayed(f"Analyzing file '{file}' [{index}/{total}]"))
    return True

def main():
    args = parse_arguments()
    
    if not args.folder:
        args.folder = ["src", "tests"]

    version = get_clang_format_version()
    if version < 18:
        print(red(f"clang-format version is {version}; EXPECTED higher or equal than 18"))
        sys.exit(1)
    
    if not Path(args.config).is_file():
        print(red(f"Error: Configuration file '{args.config}' does not exist !"))
        sys.exit(1)
    
    files = find_source_files(args.folder)
    if not files:
        print(f"No source files found in {args.folder} !")
        sys.exit(0)
    
    total_files = len(files)
    
    if not args.silent:
        print(f"Found {total_files} source files")
    
    all_passed = True
    with ThreadPoolExecutor(max_workers=args.jobs) as executor:
        results = executor.map(lambda f: run_clang_format(f, args.config, args.apply, args.silent, args.clang_format_bin, files.index(f)+1, total_files), files)
        if not all(results):
            all_passed = False
    
    if not all_passed:
        print(red("Clang-Format issues detected !"))
        sys.exit(1)
    
    if not args.silent:
        print(green("All files processed successfully !"))
    sys.exit(0)
    
if __name__ == "__main__":
    main()
