# conf

This repo is aim to be used as submodules for projects to get already designed `clang-format` and `clang-tidy` configs.
And provide scripts to call for `clang-format` / `clang-tidy` / `coverage` and `CodeChecker` with additional `.githooks`

This project suppose it is included as git's submodules or just plain folder but under the name `conf`

## clang-format
Extra args are used to set the lists of folders scanned (default list is `src` and `tests`, this list is reset at the first encountered folder arg)

`clang-format` dry mode, here only the `tests` folder will be scanned:
```
./conf/linter/clang-format.sh tests
```

`clang-format` exec mode:
```
./conf/linter/clang-format.sh -m exec
```

## clang-tidy
The first arg has to be the bazel rule that generate the compile_commands.json see [hedronvision/bazel-compile-commands-extractor](https://github.com/hedronvision/bazel-compile-commands-extractor)
Following args are used to set the folder in which clang-tidy will be executed (default list is `src` and `tests`) 
```
./conf/linter/clang-tidy.sh //:my_compile_command src tests
```

## Coverage
using the bazel rule:
```sh
./conf/coverage/coverage_html.sh //tests/units:all
```

extra flags are redirected to bazel:
ex `--instrumentation_filter` to check every but the tests folder:
```sh
./conf/coverage/coverage_html.sh //tests/units:all --instrumentation_filter="^//,-^//tests"
```

## CodeChecker
The first arg has to be the bazel rule that generate the compile_commands.json see [hedronvision/bazel-compile-commands-extractor](https://github.com/hedronvision/bazel-compile-commands-extractor)

```sh
./conf/CodeChecker/codechecker.sh //my_compile_command <codechecker_server_ip:port>/<codechecker_project_url>
```
