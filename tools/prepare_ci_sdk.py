"""Make an operator-only SDK archive for ephemeral Windows CI workers.

This is licensed development data, never a public GitHub artifact or CDN file.
Only SDK raw data and the five named runtime/linker files are included. Saved
configs, keys, env files, profiles, game archives and mods are absent. The SDK's
comment-only fileSysCheck.cfg filesystem marker is the sole config exception.
"""
import argparse
import hashlib
from pathlib import Path
import zipfile


def sdk_files(game_root):
    binaries = ['linker_pc.exe', 'mfc71.dll', 'MSVCP71.DLL', 'msvcr71.dll', 'mss32.dll']
    files = [(game_root / 'bin' / name, 'bin/' + name) for name in binaries]
    for path in sorted((game_root / 'raw').rglob('*')):
        if not path.is_file() or path.is_symlink():
            continue
        relative = path.relative_to(game_root).as_posix()
        name = path.name.lower()
        if (path.suffix.lower() in {'.cfg', '.env', '.pem', '.key'} and relative.lower() != 'raw/filesyscheck.cfg'
                or name.startswith(('.env', 'private.')) or name in ('id_rsa', 'id_ed25519')):
            continue
        files.append((path, relative))
    return files


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game-root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    files = sdk_files(args.game_root)
    with zipfile.ZipFile(args.output, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=5) as archive:
        archive.writestr('zone_source/', b'')
        archive.writestr('zone_source/english/assetlist/', b'')
        archive.writestr('zone_source/english/assetinfo/', b'')
        archive.writestr('zone/english/', b'')
        for path, relative in files:
            archive.write(path, relative)
    with args.output.open('rb') as stream:
        checksum = hashlib.file_digest(stream, 'sha256').hexdigest()
    print(str(len(files)) + ' SDK files; SHA256 ' + checksum)


if __name__ == '__main__':
    main()
