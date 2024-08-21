"""Pytest rules for Bazel"""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@rules_python//python:defs.bzl", "PyInfo", "py_common", "py_library")

PYTEST_TARGET = Label("//python/pytest:current_py_pytest_toolchain")

PY_PYTEST_TEST_ARGS_FILE = "PY_PYTEST_TEST_ARGS_FILE"

test_configs = struct(
    coverage_rc = Label("//python/pytest:coverage_rc"),
    pytest_config = Label("//python/pytest:config"),
)

def _is_pytest_test(src):
    basename = src.basename

    if basename.startswith("test_"):
        return True

    if basename.endswith("_test.py"):
        return True

    return False

def _rlocationpath(file, workspace_name):
    if file.short_path.startswith("../"):
        return file.short_path[len("../"):]

    return "{}/{}".format(workspace_name, file.short_path)

def _py_pytest_test_impl(ctx):
    # Gather args for the runner
    runner_args = [
        "--cov-config={}".format(_rlocationpath(coverage_rc, ctx.workspace_name)),
        "--pytest-config={}".format(_rlocationpath(pytest_config, ctx.workspace_name)),
    ]

    # Separate runner args from other inputs
    runner_args.append("--")

    # Add the test sources.
    runner_args.extend(sorted([src for src in ctx.file.srcs if _is_pytest_test(src)]))

    exec_requirements = {}

    # Optionally enable multi-threading
    if ctx.attr.numprocesses > 0:
        runner_args.append("--numprocesses={}".format(ctx.attr.numprocesses))
        exec_requirements["cpu"] = ctx.attr.numprocesses

    runner_args.extend(ctx.attr._extra_args[BuildSettingInfo].value)
    for arg in ctx.attr._extra_args[BuildSettingInfo].value:
        if arg.startsiwth(("--numprocesses=", "-n=")) or arg in ("--numprocesses", "-n"):
            fail("`{}` is not an acceptable extra argument for pytest. Please remove it".format(arg))

    arg_file = ctx.actions.declare_file("{}.pytest_args.txt".format(ctx.label.name))
    ctx.actions.write(
        output = arg_file,
        content = "\n".join(runner_args),
    )

    py_toolchain = ctx.toolchains[Label("@rules_python//python:toolchain_type")]
    pytest_toolchain = ctx.toolchains[Label("//python/pytest:toolchain_type")]

    py_exec_info = py_common.create_executable(
        ctx = ctx,
        toolchain = py_toolchain,
        main = ctx.file._main,
        legacy_create_init = False,
        deps = [pytest_toolchain.pytest] + ctx.attr.deps,
        is_test = True,
    )

    runfiles = py_exec_info.runfiles.merge(ctx.runfiles([
        arg_file,
        ctx.file.pytest_config,
        ctx.file.coverage_rc,
    ]))

    env = {}
    for key, value in ctx.attr.env.items():
        env[key] = ctx.expand_location(value, ctx.attr.data)

    return [
        DefaultInfo(
            executable = py_exec_info.executable,
            runfiles = runfiles,
        ),
        testing.ExecutionInfo(
            requirements = exec_requirements,
        ),
        RunEnvironmentInfo(
            environment = env | {
                PY_PYTEST_TEST_ARGS_FILE: _rlocationpath(args_file, ctx.workspace_name),
            },
        ),
        coverage_common.instrumented_files_info(
            ctx,
            source_attributes = ["srcs"],
            dependency_attributes = ["deps", "data"],
            extensions = ["py"],
        ),
    ]

_COVERAGE_ATTR = {
    # This *might* be a magic attribute to help C++ coverage work. There's no
    # docs about this; see TestActionBuilder.java
    "_collect_cc_coverage": attr.label(
        default = "@bazel_tools//tools/test:collect_cc_coverage",
        executable = True,
        cfg = "exec",
    ),
    # This *might* be a magic attribute to help C++ coverage work. There's no
    # docs about this; see TestActionBuilder.java
    "_lcov_merger": attr.label(
        default = configuration_field(fragment = "coverage", name = "output_generator"),
        cfg = "exec",
        executable = True,
    ),
}

py_pytest_test = rule(
    doc = """\
A rule which runs python tests using [pytest][pt] as the [py_test][bpt] test runner.

This rule also supports a build setting for globally applying extra flags to test invocations.
Users can add something similar to the following to their `.bazelrc` files:

```text
build --//python/pytest:extra_args=--color=yes,-vv
```

The example above will add `--colors=yes` and `-vv` arguments to the end of the pytest invocation.

Tips:

- It's common for tests to have some utility code that does not live in a test source file.
To account for this. A `py_library` can be created that contains only these sources which are then
passed to `py_pytest_test` via `deps`.

```python
load("@rules_python//python:defs.bzl", "py_library")
load("@rules_pytest//python/pytest:defs.bzl", "PYTEST_TARGET", "py_pytest_test")

py_library(
    name = "test_utils",
    srcs = [
        "tests/__init__.py",
        "tests/conftest.py",
    ],
    deps = [PYTEST_TARGET],
    testonly = True,
)

py_pytest_test(
    name = "test",
    srcs = ["tests/example_test.py"],
    deps = [":test_utils"],
)
```

[pt]: https://docs.pytest.org/en/latest/
[bpt]: https://docs.bazel.build/versions/master/be/python.html#py_test
[ptx]: https://pypi.org/project/pytest-xdist/

Args:
    name (str): The name for the current target.
    srcs (list): An explicit list of source files to test.
    coverage_rc (Label, optional): The pytest-cov configuration file to use
    pytest_config (Label, optional): The pytest configuration file to use
    numprocesses (int, optional): If set the [pytest-xdist][ptx] argument
        `--numprocesses` (`-n`) will be passed to the test.
    tags (list, optional): Tags to set on the underlying `py_test` target.
    **kwargs: Keyword arguments to forward to the underlying `py_test` target.
""",
    implementation = _py_pytest_test_impl,
    attrs = {
        "config": attr.label(
            doc = "The pytest configuration file to use.",
            allow_single_file = True,
            default = Label("//python/pytest:config"),
        ),
        "coverage_rc": attr.label(
            doc = "The pytest-cov configuration file to use.",
            allow_single_file = True,
            default = Label("//python/pytest:coverage_rc"),
        ),
        "data": attr.label_list(
            doc = "Files needed by this rule at runtime. May list file or rule targets. Generally allows any target.",
            allow_files = True,
        ),
        "deps": attr.label_list(
            doc = "The list of other libraries to be linked in to the binary target.",
            providers = [PyInfo],
        ),
        "env": attr.string_dict(
            doc = "Dictionary of strings; values are subject to `$(location)` and \"Make variable\" substitution",
            default = {},
        ),
        "numprocesses": attr.int(
            doc = (
                "If set the [pytest-xdist](https://pypi.org/project/pytest-xdist/) " +
                "argument `--numprocesses` (`-n`) will be passed to the test. Note that " +
                "the a value 0 or less indicates this flag should not be passed."
            ),
            default = 0,
        ),
        "srcs": attr.label_list(
            doc = "An explicit list of source files to test.",
            allow_files = True,
        ),
        "_extra_args": attr.label(
            doc = "TODO",
            default = Label("//python/pytest:extra_args"),
        ),
        "_main": attr.label(
            doc = "The pytest entrypoint",
            allow_single_file = True,
            default = Label("//python/pytest/private:process_wrapper.py"),
        ),
    } | _COVERAGE_ATTR,
    toolchains = [
        "@rules_python//python:toolchain_type",
        str(Label("//python/pytest:toolchain_type")),
    ],
    test = True,
)

def _py_pytest_toolchain_impl(ctx):
    pytest_target = ctx.attr.pytest

    # TODO: Default info changes behavior when it's simply forwarded.
    # To avoid this a new one is recreated.
    default_info = DefaultInfo(
        files = pytest_target[DefaultInfo].files,
        runfiles = pytest_target[DefaultInfo].default_runfiles,
    )

    return [
        platform_common.ToolchainInfo(
            pytest = ctx.attr.pytest,
        ),
        default_info,
        pytest_target[PyInfo],
        pytest_target[OutputGroupInfo],
        pytest_target[InstrumentedFilesInfo],
    ]

py_pytest_toolchain = rule(
    implementation = _py_pytest_toolchain_impl,
    doc = "A toolchain for the [pytest](https://python/pytest.readthedocs.io/en/stable/) formatter rules.",
    attrs = {
        "pytest": attr.label(
            doc = "The pytest `py_library` to use with the rules.",
            providers = [PyInfo],
            mandatory = True,
        ),
    },
)

def _current_py_pytest_toolchain_impl(ctx):
    toolchain = ctx.toolchains[str(Label("//python/pytest:toolchain_type"))]

    pytest_target = toolchain.pytest

    # TODO: Default info changes behavior when it's simply forwarded.
    # To avoid this a new one is recreated.
    default_info = DefaultInfo(
        files = pytest_target[DefaultInfo].files,
        runfiles = pytest_target[DefaultInfo].default_runfiles,
    )

    return [
        toolchain,
        default_info,
        pytest_target[PyInfo],
        pytest_target[OutputGroupInfo],
        pytest_target[InstrumentedFilesInfo],
    ]

current_py_pytest_toolchain = rule(
    doc = "A rule for exposing the current registered `py_pytest_toolchain`.",
    implementation = _current_py_pytest_toolchain_impl,
    toolchains = [
        str(Label("//python/pytest:toolchain_type")),
    ],
)

def py_pytest_test_suite(
        name,
        tests,
        args = [],
        data = [],
        **kwargs):
    """Generates a [test_suite][ts] which groups various test targets for a set of python sources.

    Given an idiomatic python project structure:
    ```text
    BUILD.bazel
    my_lib/
        __init__.py
        mod_a.py
        mod_b.py
        mod_c.py
    requirements.in
    requirements.txt
    tests/
        __init__.py
        fixtures.py
        test_mod_a.py
        test_mod_b.py
        test_mod_c.py
    ```

    This rule can be used to easily define test targets:

    ```python
    load("@rules_python//python:defs.bzl", "py_library")
    load("@rules_pytest//python/pytest:defs.bzl", "py_pytest_test_suite")

    py_library(
        name = "my_lib",
        srcs = glob(["my_lib/**/*.py"])
        imports = ["."],
    )

    py_pytest_test_suite(
        name = "my_lib_test_suite",
        # Source files containing test helpers should go here.
        # Note that the test sources are excluded. This avoids
        # a test to be updated without invalidating all other
        # targets.
        srcs = glob(
            include = ["tests/**/*.py"],
            exclude = ["tests/**/*_test.py"],
        ),
        # Any data files the tests may need would be passed here
        data = glob(["tests/**/*.json"]),
        # This field is used for dedicated test files.
        tests = glob(["tests/**/*_test.py"]),
        deps = [
            ":my_lib",
        ],
    )
    ```

    For each file passed to `tests`, a [py_pytest_test](#py_pytest_test) target will be created. From the example above,
    the user should expect to see the following test targets:
    ```text
    //:my_lib_test_suite
    //:tests/test_mod_a
    //:tests/test_mod_b
    //:tests/test_mod_c
    ```

    Additional Notes:
    - No file passed to `tests` should be passed found in the `srcs` or `data` attributes or tests will not be able
        to be individually cached.

    [pt]: https://docs.bazel.build/versions/master/be/python.html#py_test
    [ts]: https://docs.bazel.build/versions/master/be/general.html#test_suite

    Args:
        name (str): The name of the test suite
        tests (list): A list of source files, typically `glob(["tests/**/*_test.py"])`, which are converted
            into test targets.
        args (list, optional): Arguments for the underlying `py_pytest_test` targets.
        data (list, optional): A list of additional data for the test. This field would also include python
            files containing test helper functionality.
        **kwargs: Keyword arguments passed to the underlying `py_test` rule.
    """

    tests_targets = []

    common_kwargs = {
        "target_compatible_with": kwargs.get("target_compatible_with"),
        "visibility": kwargs.get("visibility"),
    }

    deps = kwargs.pop("deps", [])
    srcs = kwargs.pop("srcs", [])
    if srcs:
        test_lib_name = name + "_test_lib"
        py_library(
            name = test_lib_name,
            srcs = srcs,
            deps = deps,
            data = data,
            testonly = True,
            tags = ["manual"],
            **common_kwargs
        )
        deps = [test_lib_name] + deps

    for src in tests:
        src_name = src.name if type(src) == "Label" else src
        if not src_name.endswith(".py"):
            fail("srcs should have `.py` extensions")

        # The test name should not end with `.py`
        test_name = src_name[:-3]
        py_pytest_test(
            name = test_name,
            args = args,
            srcs = [src],
            data = data,
            deps = deps,
            **kwargs
        )

        tests_targets.append(test_name)

    native.test_suite(
        name = name,
        tests = tests_targets,
        tags = kwargs.get("tags", []),
        **common_kwargs
    )
