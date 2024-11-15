<!-- Generated with Stardoc: http://skydoc.bazel.build -->

# rules_pytest

Bazel rules for the [Pytest Python test framework](https://docs.pytest.org/en/stable/).

## Rules

- [py_pytest_test](#py_pytest_test)
- [py_pytest_test_suite](#py_pytest_test_suite)
- [py_pytest_toolchain](#py_pytest_toolchain)

---
---

<a id="current_py_pytest_toolchain"></a>

## current_py_pytest_toolchain

<pre>
current_py_pytest_toolchain(<a href="#current_py_pytest_toolchain-name">name</a>)
</pre>

A rule for exposing the current registered `py_pytest_toolchain`.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="current_py_pytest_toolchain-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |


<a id="py_pytest_test"></a>

## py_pytest_test

<pre>
py_pytest_test(<a href="#py_pytest_test-name">name</a>, <a href="#py_pytest_test-deps">deps</a>, <a href="#py_pytest_test-srcs">srcs</a>, <a href="#py_pytest_test-data">data</a>, <a href="#py_pytest_test-config">config</a>, <a href="#py_pytest_test-coverage_rc">coverage_rc</a>, <a href="#py_pytest_test-env">env</a>, <a href="#py_pytest_test-numprocesses">numprocesses</a>)
</pre>

A rule which runs python tests using [pytest][pt] as the [py_test][bpt] test runner.

This rule also supports a build setting for globally applying extra flags to test invocations.
Users can add something similar to the following to their `.bazelrc` files:

```text
build --@rules_pytest//python/pytest:extra_args=--color=yes,-vv
```

The example above will add `--colors=yes` and `-vv` arguments to the end of the pytest invocation.

Tips:

- It's common for tests to have some utility code that does not live in a test source file.
To account for this. A `py_library` can be created that contains only these sources which are then
passed to `py_pytest_test` via `deps`.

```python
load("@rules_python//python:defs.bzl", "py_library")
load("@rules_pytest//python/pytest:defs.bzl", "py_pytest_test")

py_library(
    name = "test_utils",
    srcs = [
        "tests/__init__.py",
        "tests/conftest.py",
    ],
    deps = ["@rules_pytest//python/pytest:current_py_pytest_toolchain"],
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

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="py_pytest_test-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="py_pytest_test-deps"></a>deps |  The list of other libraries to be linked in to the binary target.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="py_pytest_test-srcs"></a>srcs |  An explicit list of source files to test.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="py_pytest_test-data"></a>data |  Files needed by this rule at runtime. May list file or rule targets. Generally allows any target.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="py_pytest_test-config"></a>config |  The pytest configuration file to use.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `"@rules_pytest//python/pytest:config"`  |
| <a id="py_pytest_test-coverage_rc"></a>coverage_rc |  The pytest-cov configuration file to use.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `"@rules_pytest//python/pytest:coverage_rc"`  |
| <a id="py_pytest_test-env"></a>env |  Dictionary of strings; values are subject to `$(location)` and "Make variable" substitution   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="py_pytest_test-numprocesses"></a>numprocesses |  If set the [pytest-xdist](https://pypi.org/project/pytest-xdist/) argument `--numprocesses` (`-n`) will be passed to the test. Note that the a value 0 or less indicates this flag should not be passed.   | Integer | optional |  `0`  |


<a id="py_pytest_toolchain"></a>

## py_pytest_toolchain

<pre>
py_pytest_toolchain(<a href="#py_pytest_toolchain-name">name</a>, <a href="#py_pytest_toolchain-pytest">pytest</a>)
</pre>

A toolchain for the [pytest](https://python/pytest.readthedocs.io/en/stable/) rules.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="py_pytest_toolchain-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="py_pytest_toolchain-pytest"></a>pytest |  The pytest `py_library` to use with the rules.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |


<a id="py_pytest_test_suite"></a>

## py_pytest_test_suite

<pre>
py_pytest_test_suite(<a href="#py_pytest_test_suite-name">name</a>, <a href="#py_pytest_test_suite-tests">tests</a>, <a href="#py_pytest_test_suite-args">args</a>, <a href="#py_pytest_test_suite-data">data</a>, <a href="#py_pytest_test_suite-kwargs">kwargs</a>)
</pre>

Generates a [test_suite][ts] which groups various test targets for a set of python sources.

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


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="py_pytest_test_suite-name"></a>name |  The name of the test suite   |  none |
| <a id="py_pytest_test_suite-tests"></a>tests |  A list of source files, typically `glob(["tests/**/*_test.py"])`, which are converted into test targets.   |  none |
| <a id="py_pytest_test_suite-args"></a>args |  Arguments for the underlying `py_pytest_test` targets.   |  `[]` |
| <a id="py_pytest_test_suite-data"></a>data |  A list of additional data for the test. This field would also include python files containing test helper functionality.   |  `[]` |
| <a id="py_pytest_test_suite-kwargs"></a>kwargs |  Keyword arguments passed to the underlying `py_test` rule.   |  none |


