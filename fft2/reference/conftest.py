import pytest


def pytest_addoption(parser):
    parser.addoption("--run-slow", action="store_true", help="run N >= 2^22 FFT model tests")


def pytest_configure(config):
    config.addinivalue_line("markers", "slow: N >= 2^22 (enable with --run-slow)")


def pytest_collection_modifyitems(config, items):
    if not config.getoption("--run-slow"):
        skip = pytest.mark.skip(reason="N >= 2^22; pass --run-slow to enable")
        for item in items:
            if "slow" in item.keywords:
                item.add_marker(skip)
