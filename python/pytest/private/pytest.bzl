"""Pytest rules for Bazel"""

load("@rules_python//python:defs.bzl", "PyInfo", "py_library", "py_test")

PYTEST_TARGET = Label("//python/pytest:current_py_pytest_toolchain")

PY_PYTEST_TEST_ARGS_FILE = "PY_PYTEST_TEST_ARGS_FILE"

test_configs = struct(
    coverage_rc = Label("//python/pytest:coverage_rc"),
    pytest_config = Label("//python/pytest:config"),
)

_EXTRA_ARGS_MANIFEST = Label("//python/pytest:extra_args")

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

def _pytest_tests_manifest_impl(ctx):
    output = ctx.actions.declare_file(ctx.label.name)

    test_srcs = sorted([
        _rlocationpath(src, ctx.workspace_name)
        for src in ctx.files.srcs
        if _is_pytest_test(src)
    ])

    ctx.actions.write(
        output = output,
        content = "\n".join(test_srcs),
    )

    return DefaultInfo(
        files = depset([output]),
        runfiles = ctx.runfiles(files = [output]),
    )

_pytest_tests_manifest = rule(
    doc = "A rule for collecting files to test when running pytest",
    implementation = _pytest_tests_manifest_impl,
    attrs = {
        "srcs": attr.label_list(
            doc = "A list of python source files",
            allow_files = [".py"],
            mandatory = True,
        ),
    },
)

def py_pytest_test(
        name,
        srcs,
        coverage_rc = test_configs.coverage_rc,
        pytest_config = test_configs.pytest_config,
        numprocesses = None,
        tags = [],
        **kwargs):
    """A rule which runs python tests using [pytest][pt] as the [py_test][bpt] test runner.

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
    """
    runner_data = [
        pytest_config,
        coverage_rc,
        _EXTRA_ARGS_MANIFEST,
    ]

    # Gather args for the runner
    runner_args = [
        "--cov-config=$(rlocationpath {})".format(coverage_rc),
        "--pytest-config=$(rlocationpath {})".format(pytest_config),
        "--extra-args-manifest=$(rlocationpath {})".format(_EXTRA_ARGS_MANIFEST),
    ]

    tests_manifest_name = name + ".pytest_tests_manifest"
    _pytest_tests_manifest(
        name = tests_manifest_name,
        srcs = srcs,
        tags = ["manual"],
        testonly = True,
    )
    runner_args.append(
        "--tests-manifest=$(rlocationpath {})".format(tests_manifest_name),
    )
    runner_data.append(tests_manifest_name)

    # Create an unfrozen list.
    tags = tags[:] if tags else []

    # Optionally enable multi-threading
    if numprocesses != None:
        runner_args.append("--numprocesses={}".format(numprocesses))
        cpu_tag = "cpu:{}".format(numprocesses)
        if cpu_tag not in tags:
            tags.append(cpu_tag)

    # Separate runner args from other inputs
    runner_args.append("--")

    runner_deps = [
        Label("//python/pytest:current_py_pytest_toolchain"),
        Label("//python/pytest/private:runfiles_wrapper"),
    ]

    runner_main = Label("//python/pytest/private:process_wrapper.py")

    if "main" in kwargs:
        fail("The attribute `main` should not be used as it's replaced by a test runner")

    py_test(
        name = name,
        srcs = [runner_main] + srcs,
        main = runner_main,
        deps = runner_deps + kwargs.pop("deps", []),
        data = runner_data + kwargs.pop("data", []),
        args = runner_args + kwargs.pop("args", []),
        tags = tags,
        legacy_create_init = 0,
        **kwargs
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
        coverage_rc = test_configs.coverage_rc,
        pytest_config = test_configs.pytest_config,
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
        coverage_rc (Label, optional): The pytest-cov configuration file to use.
        pytest_config (Label, optional): The pytest configuration file to use.
        **kwargs: Keyword arguments passed to the underlying `py_test` rule.
    """

    tests_targets = []

    deps = kwargs.pop("deps", [])
    srcs = kwargs.pop("srcs", [])
    if srcs:
        test_lib_name = name + "_test_lib"
        py_library(
            name = test_lib_name,
            srcs = srcs,
            deps = deps,
            data = data,
            tags = ["manual"],
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
            coverage_rc = coverage_rc,
            pytest_config = pytest_config,
            args = args,
            srcs = [src],
            data = data,
            deps = deps,
            **kwargs
        )

        tests_targets.append(test_name)

    common_kwargs = {
        "tags": kwargs.get("tags", []),
        "target_compatible_with": kwargs.get("target_compatible_with"),
        "visibility": kwargs.get("visibility"),
    }

    native.test_suite(
        name = name,
        tests = tests_targets,
        **common_kwargs
    )
