"""Mirror a map directory listing. Standard library only; safe to rerun after interruption."""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from html.parser import HTMLParser
import json
import os
from pathlib import Path, PurePosixPath
import re
import threading
import time
from urllib.parse import unquote, urljoin, urlsplit
from urllib.request import Request, urlopen


class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []

    def handle_starttag(self, tag, attrs):
        if tag == 'a':
            self.links.extend(value for name, value in attrs if name == 'href' and value)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--url', required=True)
    parser.add_argument('--destination', required=True, type=Path)
    parser.add_argument('--state-directory', type=Path, required=True)
    parser.add_argument('--workers', type=int, choices=range(1, 9), default=4)
    args = parser.parse_args()
    base_url = args.url.rstrip('/') + '/'
    base = urlsplit(base_url)
    if base.scheme not in ('http', 'https'):
        parser.error('Use an HTTP or HTTPS directory listing.')
    destination = args.destination.resolve()
    destination.mkdir(parents=True, exist_ok=True)
    state_dir = args.state_directory.resolve()
    state_dir.mkdir(parents=True, exist_ok=True)
    state = {'status': 'indexing', 'source': base_url, 'destination': str(destination),
             'pid': os.getpid(), 'started_at': datetime.now(timezone.utc).isoformat(),
             'directories': 0, 'files_total': 0, 'downloaded': 0, 'skipped': 0,
             'bytes_downloaded': 0, 'errors': [], 'active': {}}
    lock = threading.Lock()

    def save():
        state['updated_at'] = datetime.now(timezone.utc).isoformat()
        temporary = state_dir / 'status.tmp'
        temporary.write_text(json.dumps(state, indent=2), encoding='utf-8')
        for attempt in range(8):
            try:
                temporary.replace(state_dir / 'status.json')
                return
            except PermissionError:
                # Windows readers may briefly hold the old status file open.
                # A progress display must not fail an otherwise valid map transfer.
                time.sleep(0.025 * (2 ** attempt))
        print('Progress file is temporarily locked; map downloads continue.', flush=True)

    def get(url, headers=None):
        response = urlopen(Request(url, headers={'User-Agent': 'ApX-Deathrun-MapDownloader/1.0', **(headers or {})}), timeout=45)
        final = urlsplit(response.url)
        if final.netloc != base.netloc or not final.path.startswith(base.path):
            response.close()
            raise ValueError('Redirect outside requested server directory')
        return response

    def list_directory(url):
        for attempt in range(4):
            try:
                with get(url) as response:
                    listing = Links()
                    listing.feed(response.read(8 * 1024 * 1024).decode('utf-8', errors='replace'))
                results = []
                for href in listing.links:
                    absolute = urljoin(url, href)
                    parsed = urlsplit(absolute)
                    if parsed.netloc != base.netloc or not parsed.path.startswith(base.path) or parsed.query or parsed.fragment:
                        continue
                    relative = unquote(parsed.path[len(base.path):])
                    parts = PurePosixPath(relative).parts
                    if not parts or any(part in ('.', '..') or re.search(r'[<>:"\\|?*\x00-\x1f]', part) for part in parts):
                        continue
                    results.append((absolute, relative, parsed.path.endswith('/')))
                return results
            except Exception:
                if attempt == 3:
                    raise
                time.sleep(2 ** attempt)

    with lock:
        save()
    pending = [base_url]
    visited = set()
    files = {}
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        while pending:
            batch = [url for url in pending if url not in visited]
            visited.update(batch)
            pending = []
            for future in as_completed({pool.submit(list_directory, url): url for url in batch}):
                try:
                    for url, relative, directory in future.result():
                        if directory:
                            if url not in visited:
                                pending.append(url)
                        else:
                            files[relative] = url
                    state['directories'] += 1
                except Exception as error:
                    state['errors'].append(f'Listing: {error}')
                state['files_total'] = len(files)
                save()
    manifest = [{'path': path, 'url': url} for path, url in sorted(files.items())]
    (state_dir / 'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    state['status'] = 'downloading'
    save()
    print(f'Indexed {state["directories"]} directories, {len(files)} files.', flush=True)

    def download(relative, url):
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        # Resolve after creating the parent: Windows can return inconsistent
        # canonical paths when several workers resolve a not-yet-created folder.
        if not target.parent.resolve().is_relative_to(destination):
            raise ValueError(f'Unsafe local parent: {relative}')
        if target.is_symlink():
            raise ValueError(f'Refusing to replace a linked file: {relative}')
        partial = target.with_name(target.name + '.apx-download.part')
        with lock:
            state['active'][relative] = 0
            save()
        try:
            for attempt in range(4):
                try:
                    offset = partial.stat().st_size if partial.exists() else 0
                    headers = {'Range': f'bytes={offset}-'} if offset else {}
                    with get(url, headers) as response:
                        append = response.status == 206 and offset > 0
                        if append and not response.headers.get('Content-Range', '').startswith(f'bytes {offset}-'):
                            raise ValueError('Unexpected Content-Range')
                        expected = response.headers.get('Content-Length')
                        expected = int(expected) + (offset if append else 0) if expected else None
                        if not append:
                            offset = 0
                            if target.exists() and expected is not None and target.stat().st_size == expected:
                                with lock:
                                    state['skipped'] += 1
                                return
                        with partial.open('ab' if append else 'wb') as output:
                            last_save = time.monotonic()
                            while True:
                                chunk = response.read(1024 * 1024)
                                if not chunk:
                                    break
                                output.write(chunk)
                                offset += len(chunk)
                                with lock:
                                    state['bytes_downloaded'] += len(chunk)
                                    state['active'][relative] = offset
                                    if time.monotonic() - last_save > 3:
                                        save()
                                        last_save = time.monotonic()
                        if expected is not None and offset != expected:
                            raise OSError(f'Incomplete transfer: {offset}/{expected}')
                    if target.exists():
                        backup = target.with_name(target.name + '.previous-' + datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
                        target.replace(backup)
                    partial.replace(target)
                    with lock:
                        state['downloaded'] += 1
                        print(f'[{state["downloaded"] + state["skipped"]}/{len(files)}] {relative}', flush=True)
                    return
                except Exception:
                    if attempt == 3:
                        raise
                    time.sleep(2 ** attempt)
        finally:
            with lock:
                state['active'].pop(relative, None)
                save()

    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = {pool.submit(download, relative, url): relative for relative, url in files.items()}
        for future in as_completed(futures):
            try:
                future.result()
            except Exception as error:
                with lock:
                    state['errors'].append(f'{futures[future]}: {error}')
                    save()
    state['status'] = 'complete' if not state['errors'] else 'finished_with_errors'
    save()
    print(json.dumps({key: value for key, value in state.items() if key not in ('active',)}), flush=True)
    return 1 if state['errors'] else 0


if __name__ == '__main__':
    raise SystemExit(main())
