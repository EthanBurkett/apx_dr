"""Run the SDK-free core suite or full hydrated-asset/SDK checks.

Core intentionally excludes binary-image assertions. It retains progression
boundary, inventory, permission, navigation and traffic decision tests.
"""
import argparse
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
ASSET_MODULES = {"test_interface_assets", "test_menu_assets"}
ASSET_TESTS = {"test_progression.Progression.test_tables_and_all_custom_assets_are_complete",
               "test_repository.Repository.test_authoring_originals_are_retained_for_every_optimized_texture"}


def flatten(suite):
    for test in suite:
        if isinstance(test, unittest.TestSuite):
            yield from flatten(test)
        else:
            yield test


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", choices=("core", "full"), default="core")
    parser.add_argument("--game-root", type=Path)
    args = parser.parse_args()
    full = args.suite == "full"
    commands = [[sys.executable, str(ROOT / "tools/repo_audit.py")] + (["--assets"] if full else []),
                [sys.executable, str(ROOT / "tools/validate.py")] + ([] if full else ["--source-only"])]
    if args.game_root:
        commands[-1] += ["--game-root", str(args.game_root)]
    for command in commands:
        result = subprocess.run(command, cwd=ROOT)
        if result.returncode:
            return result.returncode
    sys.path.insert(0, str(ROOT / "tests"))
    sys.path.insert(0, str(ROOT / "tools"))
    tests = unittest.defaultTestLoader.discover(str(ROOT / "tests"))
    selected = [test for test in flatten(tests) if full or
                (test.id().split(".")[0] not in ASSET_MODULES and test.id() not in ASSET_TESTS)]
    print(f"Running {args.suite}: {len(selected)} tests", flush=True)
    return not unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(selected)).wasSuccessful()


if __name__ == "__main__":
    raise SystemExit(main())
