"""Make an operator-only SDK archive for ephemeral Windows CI workers.

This is licensed development data, never a public GitHub artifact or CDN file.
Only SDK raw data and the five named runtime/linker files are included. Saved
configs, keys, env files, profiles, game archives and mods are absent. The SDK's
comment-only fileSysCheck.cfg filesystem marker is the sole config exception.
"""
import argparse
import hashlib
from pathlib import Path, PurePosixPath
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


def stock_images(game_root, existing):
    images = {}
    for path in sorted((game_root / 'main').glob('*.iwd')):
        with zipfile.ZipFile(path) as archive:
            for info in archive.infolist():
                name = info.filename.replace('\\', '/')
                relative = PurePosixPath(name)
                destination = 'raw/' + name
                if (name.lower().startswith('images/') and name.lower().endswith('.iwi')
                        and not relative.is_absolute() and '..' not in relative.parts
                        and destination.lower() not in existing):
                    images[destination.lower()] = (path, info.filename)
    return images


def append_stock_images(archive, game_root):
    existing = {name.lower() for name in archive.namelist()}
    images = stock_images(game_root, existing)
    groups = {}
    for destination, (path, source) in images.items():
        groups.setdefault(path, []).append((destination, source))
    for path, entries in groups.items():
        with zipfile.ZipFile(path) as source:
            for destination, name in entries:
                with source.open(name) as reader, archive.open(destination, 'w') as writer:
                    while data := reader.read(1024 * 1024):
                        writer.write(data)
    return len(images)


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
        count = append_stock_images(archive, args.game_root)
    with args.output.open('rb') as stream:
        checksum = hashlib.file_digest(stream, 'sha256').hexdigest()
    print(str(len(files)) + ' SDK files plus ' + str(count) + ' stock texture fallbacks; SHA256 ' + checksum)


if __name__ == '__main__':
    main()
