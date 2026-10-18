"""Audit publishable files, documentation links, tool coverage and LFS hydration.

Private configs are excluded by path before opening files. Credential diagnostics
report only filenames and line numbers, never values. No network access.
"""
import argparse
from pathlib import Path
import re
import subprocess
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
LFS_HEADER = b"version https://git-lfs.github.com/spec/v1"
LOCAL_DIRS = {"build", "dist", "content-check", ".codex-backups", "graphify-out", ".graphify_cache", "__pycache__"}
SECRET_NAMES = {"rcon_password", "g_password", "sv_privatepassword"}


def forbidden(path):
    path = Path(path)
    name = path.name.lower()
    return (bool(path.parts and path.parts[0].lower() in LOCAL_DIRS) or '__pycache__' in path.parts
            or (name == "private.cfg" or name.startswith("private.") and name.endswith(".cfg")) and name != "private.example.cfg"
            or name == ".env" or name.startswith(".env.") and name != ".env.example"
            or path.suffix.lower() in {".pem", ".key", ".pfx", ".ff", ".iwd", ".log"})


def credential_errors(path, text):
    errors = []
    for number, line in enumerate(text.splitlines(), 1):
        match = re.match(r'^\s*set(?:a|s)?\s+(\w+)\s+(.+?)\s*(?://.*)?$', line, re.I)
        if match and (match[1].lower() in SECRET_NAMES or match[1].lower().startswith("dr_admin_loginpass_")):
            value = match[2].strip().strip('"').strip()
            if value:
                errors.append(f"{path}:{number}: nonempty credential assignment (value redacted)")
    return errors


def link_errors(root, path):
    text = path.read_text(encoding="utf8")
    # Ignore examples inside fenced code, where paths can be illustrative.
    text = re.sub(r"(?ms)^```.*?^```[^\n]*", "", text)
    targets = re.findall(r'!?\[[^\]]*\]\(([^)\n]+)\)', text)
    targets += re.findall(r'<img\b[^>]*\bsrc="([^"]+)"', text)
    errors = []
    for target in targets:
        target = target.strip().strip("<>").split(" ", 1)[0]
        if not target or re.match(r"^[a-z][a-z0-9+.-]*:", target, re.I) or target.startswith("#"):
            continue
        target = unquote(target.split("#", 1)[0].split("?", 1)[0])
        resolved = (path.parent / target).resolve()
        if not resolved.is_relative_to(root.resolve()) or not resolved.exists():
            errors.append(f"{path.relative_to(root)}: broken local link: {target}")
    return errors


def git_paths(root, staged=False):
    args = ["git", "-C", str(root), "ls-files", "-z", "--cached"]
    if not staged:
        args += ["--others", "--exclude-standard"]
    result = subprocess.run(args, capture_output=True, check=True)
    return sorted(set(p for p in result.stdout.decode("utf8").split("\0") if p))


def audit(root=ROOT, assets=False):
    errors = []
    tracked = git_paths(root, staged=True)
    for name in tracked:
        if forbidden(name):
            errors.append(f"Forbidden file in Git index: {name}")
    # Exclusion precedes file reads, even when an unsafe path is staged.
    paths = [root / name for name in git_paths(root) if not forbidden(name)]
    for path in paths:
        if path.suffix.lower() == ".cfg" and path.is_file():
            errors += credential_errors(path.relative_to(root), path.read_text(encoding="cp1252"))
    for path in [root / "README.md", root / "CONTRIBUTING.md", root / "SECURITY.md", root / "LICENSE.md", *sorted((root / "docs").glob("*.md"))]:
        if path.exists():
            errors += link_errors(root, path)
    reference = (root / "docs/TOOLING.md").read_text(encoding="utf8")
    for path in (root / "tools").rglob("*"):
        if path.suffix in {".py", ".ps1", ".cs"} and "__pycache__" not in path.parts:
            name = path.relative_to(root).as_posix()
            if name not in reference:
                errors.append(f"Tool missing from docs/TOOLING.md: {name}")
    if assets:
        for path in paths:
            relative = path.relative_to(root).as_posix()
            is_lfs = (relative.startswith(("assets/", "server/bin/"))
                      or relative.startswith("art/source-images/") and path.suffix == ".iwi"
                      or path.suffix.lower() in {".png", ".gif"} and not relative.startswith("docs/images/")
                      or relative in {"server/apx-cod4x-source.zip", "tools/iwi2dds.exe"})
            if is_lfs and path.is_file():
                with path.open("rb") as stream:
                    if stream.read(len(LFS_HEADER)) == LFS_HEADER:
                        errors.append(f"Unhydrated LFS file: {relative}; run git lfs pull")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--assets", action="store_true", help="Also reject unhydrated binary pointers.")
    args = parser.parse_args()
    errors = audit(assets=args.assets)
    for error in errors:
        print("ERROR:", error)
    if not errors:
        print("PASS: repository paths, public configs, documentation links and tool coverage.")
    return bool(errors)


if __name__ == "__main__":
    raise SystemExit(main())
