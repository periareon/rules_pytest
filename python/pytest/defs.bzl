"""# rules_pytest

Bazel rules for the [Pytest Python test framework](https://docs.pytest.org/en/stable/).

## Rules

- [py_pytest_test](#py_pytest_test)
- [py_pytest_test_suite](#py_pytest_test_suite)
- [py_pytest_toolchain](#py_pytest_toolchain)

---
---
"""

load(
    "//python/pytest/private:pytest.bzl",
    _current_py_pytest_toolchain = "current_py_pytest_toolchain",
    _py_pytest_test = "py_pytest_test",
    _py_pytest_test_suite = "py_pytest_test_suite",
    _py_pytest_toolchain = "py_pytest_toolchain",
)

current_py_pytest_toolchain = _current_py_pytest_toolchain
py_pytest_test = _py_pytest_test
py_pytest_test_suite = _py_pytest_test_suite
py_pytest_toolchain = _py_pytest_toolchain
