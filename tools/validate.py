"""Optional, standard-library-only checks: python tools/validate.py.

The SDK linker packs GSC as raw text. These checks catch common packaging and
refactoring errors, but only CoD4x can compile and execute the scripts fully.
"""
import argparse
import csv
import json
from pathlib import Path
import re
import sys

from gsc import functions, mask


def read(path):
    return path.read_text(encoding='cp1252')


def inspect(root, game_root, source_only=False):
    errors = []
    project = json.loads((root / 'project.json').read_text())
    sdk_file = root / 'ui/sdk_dependencies.json'
    sdk = json.loads(sdk_file.read_text()) if source_only and sdk_file.is_file() else {}
    sources = {}
    for folder in project['sourceRoots']:
        base = root / folder
        for path in base.rglob('*'):
            if path.is_file():
                name = path.relative_to(base).as_posix().lower()
                if name in sources: errors.append(f'Overlapping source roots: {name}')
                sources[name] = path
    source_root = root / 'src'
    scripts = {}
    for directory in ('braxi', 'plugins', 'maps'):
        for path in (source_root / directory).rglob('*.gsc'):
            name = path.relative_to(source_root).as_posix().lower()
            text = read(path)
            code = mask(text)
            stack = []
            pairs = {')': '(', ']': '[', '}': '{'}
            for offset, char in enumerate(code):
                if char in '([{':
                    stack.append((char, offset))
                elif char in pairs:
                    if not stack or stack[-1][0] != pairs[char]:
                        errors.append(f'{name}:{code[:offset].count(chr(10)) + 1}: unmatched {char}')
                        break
                    stack.pop()
            if stack:
                errors.append(f'{name}: unclosed delimiter {stack[-1][0]}')
            try:
                definitions = functions(text)
            except ValueError as error:
                errors.append(f'{name}: {error}')
                definitions = []
            names = [fn.name.lower() for fn in definitions]
            if len(names) != len(set(names)):
                errors.append(f'{name}: duplicate function names')
            scripts[name] = (text, code, definitions)

    assets = set()
    packaged = set()
    manifest_lines = [line for fragment in sorted((root / project['manifestDirectory']).glob('*.csv')) for line in read(fragment).splitlines()]
    for row in csv.reader(line for line in manifest_lines if line.strip() and not line.lstrip().startswith('//')):
        if len(row) < 2:
            errors.append(f'mod.csv: invalid row {row}')
            continue
        kind, name = row[0].strip().lower(), row[1].strip().lower()
        if (kind, name) in assets:
            errors.append(f'mod.csv: duplicate {kind},{name}')
        assets.add((kind, name))
        if kind in ('rawfile', 'menufile', 'stringtable', 'xmodel'):
            relative = f'xmodel/{name}' if kind == 'xmodel' else name
            if relative not in sources and not (game_root / 'raw' / relative).is_file() and name not in sdk.get(kind, []):
                errors.append(f'mod.csv: missing {kind} input {name}')
        if kind == 'rawfile' and name.endswith('.gsc'):
            packaged.add(name.replace('\\', '/'))

    for name in sorted(packaged & scripts.keys()):
        text, code, definitions = scripts[name]
        own = {fn.name.lower(): fn for fn in definitions}
        imported = set(own)
        for match in re.finditer(r'#include\s+([\w\\/]+)\s*;', code):
            dependency = match[1].replace('\\', '/').lower() + '.gsc'
            if dependency in scripts:
                imported.update(fn.name.lower() for fn in scripts[dependency][2])
                if dependency not in packaged:
                    errors.append(f'{name}: import missing from mod.csv: {dependency}')
            elif not (game_root / 'raw' / dependency).is_file() and not (source_only and not dependency.startswith(('braxi/', 'plugins/'))):
                errors.append(f'{name}: missing SDK import {dependency}')
        for match in re.finditer(r'([\w\\/]+)::(\w+)', code):
            dependency = match[1].replace('\\', '/').lower() + '.gsc'
            if dependency not in scripts:
                if not (game_root / 'raw' / dependency).is_file() and not (source_only and not dependency.startswith(('braxi/', 'plugins/'))):
                    # These two generated scripts ship in the map fastfile, outside the mod.
                    stem = Path(name).stem
                    map_generated = {f'maps/createart/{stem}_art.gsc', f'maps/mp/{stem}_fx.gsc'}
                    if name.startswith('maps/mp/') and '/gametypes/' not in name and dependency in map_generated:
                        continue
                    errors.append(f'{name}: missing script {dependency}')
                continue
            if dependency not in packaged:
                errors.append(f'{name}: qualified dependency missing from mod.csv: {dependency}')
            available = {fn.name.lower() for fn in scripts[dependency][2]}
            if match[2].lower() not in available:
                errors.append(f'{name}: undefined function {dependency}::{match[2]}')
        for match in re.finditer(r'(?<![\w\\])::(\w+)', code):
            if match[1].lower() not in own:
                errors.append(f'{name}: undefined local function pointer ::{match[1]}')
        # Detect calls left behind after a function was moved out of _mod.gsc.
        api = scripts.get('braxi/_mod.gsc', ('', '', []))[2]
        moved = {fn.name.lower() for fn in api if fn.name.lower() != 'main'}
        common_helpers = {fn.name.lower() for fn in scripts.get('braxi/_common.gsc', ('', '', []))[2]}
        for fn in definitions:
            body = code[fn.body_start:fn.end]
            for match in re.finditer(r'(?<![\w:\\])\b(\w+)\s*\(', body):
                called = match[1].lower()
                if called in moved and called not in imported:
                    errors.append(f'{name}::{fn.name}: unqualified moved function {match[1]}')
                elif called in common_helpers and called not in imported:
                    errors.append(f'{name}::{fn.name}: missing _common import for {match[1]}')

    # The UI and persistent stat IDs depend on these tables remaining contiguous.
    for filename in ('characterTable.csv', 'sprayTable.csv', 'itemTable.csv', 'abilityTable.csv'):
        rows = [row for row in csv.reader(read(source_root / 'mp' / filename).splitlines()) if row]
        for number, row in enumerate(rows, 1):
            if len(row) < 3 or row[:2] != [str(number), str(number - 1)]:
                errors.append(f'mp/{filename}: row {number} must keep sequential lookup and stat IDs')
    # Validate project includes, menu components and the complete runtime config tree.
    for name, path in sources.items():
        if path.suffix not in ('.menu', '.inc'):
            continue
        for match in re.finditer(r'#include\s+"([^"]+)"', mask(read(path), strings=False)):
            dependency = match[1].lower()
            if dependency not in sources and not (game_root / 'raw' / dependency).is_file() and dependency not in sdk.get('include', []):
                errors.append(f'{name}: missing UI include {dependency}')
    configs = {}
    for item in project['looseConfigs']:
        path = root / item['source']
        if path.is_dir():
            for child in path.rglob('*.cfg'):
                configs[item['path'] + '/' + child.relative_to(path).as_posix()] = child
        elif path.is_file():
            configs[item['path']] = path
        elif not item.get('optional', False):
            errors.append(f'Missing configuration {path}')
    configs.update({name: root / 'config' / name for name in ('dr_songs.cfg', 'dr_sprays.cfg')})
    edges = {}
    for name, path in configs.items():
        edges[name] = []
        # Private config is an opaque, optional operator input. Never open it.
        if path.name.lower() == 'private.cfg':
            continue
        for match in re.finditer(r'(?im)^\s*exec\s+([\w./-]+)', read(path)):
            dependency = match[1]
            if dependency not in configs:
                if dependency != 'config/private.cfg': errors.append(f'{name}: missing config {dependency}')
            else: edges[name].append(dependency)
    def visit(name, active):
        if name in active:
            errors.append('Configuration include cycle: ' + ' -> '.join([*active, name]))
            return
        for child in edges.get(name, []): visit(child, [*active, name])
    visit('server.cfg', [])
    return errors, len(scripts), len(packaged)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument('--game-root', type=Path)
    parser.add_argument('--source-only', action='store_true', help='Skip SDK-owned imports/includes and stock xmodels; still check local references.')
    args = parser.parse_args()
    root = args.root.resolve()
    errors, total, packaged = inspect(root, (args.game_root or root.parent.parent).resolve(), args.source_only)
    if errors:
        for error in errors:
            print(f'ERROR: {error}', file=sys.stderr)
        return 1
    print(f'PASS: {total} GSC files inspected, {packaged} packaged scripts; references, tables and configs valid.')
    print('CoD4x runtime compilation and multiplayer testing are still required.')
    if args.source_only:
        print('Source-only mode: SDK-owned dependencies and binary asset payloads are not verified.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
