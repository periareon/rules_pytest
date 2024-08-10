"""Pytest dependencies"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

# buildifier: disable=unnamed-macro
def rules_pytest_dependencies():
    """Defines pytest dependencies"""
    maybe(
        http_archive,
        name = "rules_python",
        sha256 = "778aaeab3e6cfd56d681c89f5c10d7ad6bf8d2f1a72de9de55b23081b2d31618",
        strip_prefix = "rules_python-0.34.0",
        url = "https://github.com/bazelbuild/rules_python/releases/download/0.34.0/rules_python-0.34.0.tar.gz",
    )

    maybe(
        http_archive,
        name = "rules_req_compile",
        sha256 = "934c221bec5c1862d91f760d17224e5b5662aa097d595cdd197af3089cd63817",
        urls = ["https://github.com/sputt/req-compile/releases/download/1.0.0rc23/rules_req_compile-v1.0.0rc23.tar.gz"],
    )
