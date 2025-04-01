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

def get_clang_tidy_version():
    try:
        output = subprocess.check_output(["clang-tidy", "--version"], stderr=subprocess.DEVNULL, text=True)
        version = int(output.split()[3].split('.')[0])  # Extract major version
        return version
    except (subprocess.CalledProcessError, FileNotFoundError, IndexError, ValueError):
        print(red("clang-tidy is not installed or not found in PATH."))
        sys.exit(1)

def parse_arguments():
    parser = argparse.ArgumentParser(description="Run clang-tidy on C/C++ files.")
    parser.add_argument("bazel_cmd", help="Bazel command line argument")
    parser.add_argument("-p", "--json", default="compile_commands.json", help="Path to compile_commands.json")
    parser.add_argument("-c", "--config", action="append", help="Path to .clang-tidy config (can be specified multiple times)")
    parser.add_argument("--enable-headers", action="store_true", help="Include header files in search")
    parser.add_argument("--apply", action="store_true", help="Apply fixes with clang-tidy")
    parser.add_argument("--silent", action="store_true", help="Suppress output messages")
    parser.add_argument("search_list", nargs="*", default=["src", "tests"], help="Directories to search for source files")
    return parser.parse_args()

def find_source_files(search_list, include_headers):
    extensions = [".c", ".cc", ".cpp", ".cxx"]
    if include_headers:
        extensions.extend([".h", ".hh", ".hpp", ".hxx"])
    
    files = []
    for directory in search_list:
        for ext in extensions:
            files.extend(Path(directory).rglob(f"*{ext}"))
    return files

def run_clang_tidy(file, configs, json_db, apply, silent, index, total):
    for config in configs:
        config_print = ""
        if len(configs) > 1:
            config_print = f"<{config}> "
        cmd = ["clang-tidy", f"--config-file={config}", "-p", json_db, str(file)]
        if apply:
            cmd.insert(2, "--fix")
        
        result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if result.returncode != 0:
            print(red(f"Analyzing file '{file}' {config_print}[{index}/{total}]"))
            print(result.stderr, file=sys.stderr)
            print(result.stdout, file=sys.stdout)
            return False
        elif not silent:
            print(grayed(f"Analyzing file '{file}' {config_print}[{index}/{total}]"))
    return True

def main():
    args = parse_arguments()

    if not args.config:
        args.config = ["./conf/linter/RustLike/.clang-tidy"]
    
    version = get_clang_tidy_version()
    if version < 18:
        print(red(f"clang-tidy version is {version}; EXPECTED higher or equal than 18"))
        sys.exit(1)
    
    for config in args.config:
        if not Path(config).is_file():
            print(red(f"Error: Configuration file '{config}' does not exist !"))
            sys.exit(1)
        
    subprocess.run(["bazelisk", "run", args.bazel_cmd], check=True)
    
    files = find_source_files(args.search_list, args.enable_headers)
    if not files:
        print(f"No source files found in {args.search_list} !")
        sys.exit(0)
    
    total_files = len(files)

    if not args.silent:
        print(f"Found {total_files} source files")
    
    all_passed = True
    with ThreadPoolExecutor(max_workers=os.cpu_count() or 16) as executor:
        results = executor.map(lambda f: run_clang_tidy(f, args.config, args.json, args.apply, args.silent, files.index(f)+1, total_files), files)
        if not all(results):
            all_passed = False
    
    if not all_passed:
        print(red("Clang-Tidy issues detected !"))
        sys.exit(1)
    
    if not args.silent:
        print(green("All files processed successfully !"))
    sys.exit(0)
    
if __name__ == "__main__":
    main()
