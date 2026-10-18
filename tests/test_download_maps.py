"""Exercise the downloader against a local directory listing, never a public server."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json
import subprocess
import sys
import tempfile
import threading
import unittest


class MapDownloadTests(unittest.TestCase):
    def test_mirror_resume_skip_and_previous_file_preservation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            public = root / 'public'
            map_dir = public / 'usermaps' / 'mp_fixture'
            map_dir.mkdir(parents=True)
            (map_dir / 'mp_fixture.ff').write_bytes(b'fastfile fixture' * 1024)
            (map_dir / 'mp_fixture.iwd').write_bytes(b'iwd fixture' * 512)
            (public / 'outside.txt').write_text('must not download')
            target = root / 'downloaded'
            (target / 'mp_fixture').mkdir(parents=True)
            (target / 'mp_fixture/mp_fixture.ff').write_bytes(b'previous map')
            (target / 'mp_fixture/mp_fixture.iwd.apx-download.part').write_bytes(b'partial')

            class Handler(SimpleHTTPRequestHandler):
                def __init__(self, *args, **kwargs):
                    super().__init__(*args, directory=str(public), **kwargs)

                def log_message(self, *args):
                    pass

            server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                script = Path(__file__).resolve().parents[1] / 'tools/download_maps.py'
                command = [sys.executable, str(script), '--url',
                           f'http://127.0.0.1:{server.server_port}/usermaps/',
                           '--destination', str(target), '--state-directory', str(root / 'state')]
                first = subprocess.run(command, capture_output=True, text=True, timeout=30)
                self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
                for name in ('mp_fixture.ff', 'mp_fixture.iwd'):
                    self.assertEqual((target / 'mp_fixture' / name).read_bytes(), (map_dir / name).read_bytes())
                backups = list((target / 'mp_fixture').glob('*.previous-*'))
                self.assertEqual(len(backups), 1)
                self.assertEqual(backups[0].read_bytes(), b'previous map')
                self.assertFalse((target / 'outside.txt').exists())
                self.assertFalse(list(target.rglob('*.apx-download.part')))
                second = subprocess.run(command, capture_output=True, text=True, timeout=30)
                self.assertEqual(second.returncode, 0, second.stdout + second.stderr)
                state = json.loads((root / 'state/status.json').read_text())
                self.assertEqual(state['status'], 'complete')
                self.assertEqual(state['skipped'], 2)
                self.assertEqual(state['downloaded'], 0)
                self.assertEqual(state['errors'], [])
            finally:
                server.shutdown()
                server.server_close()
                thread.join(timeout=5)


if __name__ == '__main__':
    unittest.main()
