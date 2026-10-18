"""Release ingestion rejects credentials, traversal and archive type attacks."""
import importlib.util
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest
import sys
import os
import subprocess

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
spec = importlib.util.spec_from_file_location('server_deploy', ROOT / 'server/linux/deploy.py')
deploy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deploy)


class Deployment(unittest.TestCase):
    @unittest.skipUnless(os.name == 'nt', 'Windows key permissions')
    def test_windows_ssh_key_has_only_the_current_owner_access_rule(self):
        from deploy import secure_windows_key
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'identity'
            path.write_text('test key placeholder')
            secure_windows_key(path)
            shell = str(Path(os.environ['SystemRoot']) / 'System32/WindowsPowerShell/v1.0/powershell.exe')
            script = '''$acl = [System.IO.File]::GetAccessControl($env:APX_SSH_IDENTITY)
$rules = @($acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]))
$sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
if ($rules.Count -ne 1 -or $rules[0].IdentityReference.Value -ne $sid -or !$acl.AreAccessRulesProtected) { exit 1 }
'''
            subprocess.run([shell, '-NoProfile', '-NonInteractive', '-Command', script],
                           env=dict(os.environ, APX_SSH_IDENTITY=str(path)), check=True)

    def test_private_sdk_keeps_password_dialog_but_excludes_saved_credentials(self):
        from prepare_ci_sdk import sdk_files
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'raw/ui_mp').mkdir(parents=True)
            for name in ['password.menu', 'private.cfg', 'bunny.env', '.env.production', 'id_ed25519']:
                (root / 'raw/ui_mp' / name).write_text('test')
            (root / 'raw/fileSysCheck.cfg').write_text('// filesystem marker')
            names = {name for _, name in sdk_files(root)}
            self.assertIn('raw/ui_mp/password.menu', names)
            self.assertIn('raw/fileSysCheck.cfg', names)
            self.assertFalse(names.intersection({'raw/ui_mp/' + name for name in ['private.cfg', 'bunny.env', '.env.production', 'id_ed25519']}))

    def test_release_paths_cannot_write_code_keys_or_escape(self):
        for name in ['../outside', '/etc/passwd', 'config/../../outside.cfg',
                     'config/private.cfg', 'config/private.example.cfg',
                     'config\\server\\x.cfg', 'bunny.env', 'server/linux/deploy.py',
                     'apx_cod4x_dedrun', 'config/server/key.pem']:
            self.assertFalse(deploy.allowed_member(name), name)
        for name in ['mod.ff', 'apx_dr.iwd', 'config/server/rules.cfg', 'deathrun.cfg']:
            self.assertTrue(deploy.allowed_member(name), name)

    def test_malicious_archive_is_rejected_before_extraction(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for kind in ('link', 'duplicate', 'escape'):
                archive = root / (kind + '.tar')
                with tarfile.open(archive, 'w') as bundle:
                    info = tarfile.TarInfo('../escape' if kind == 'escape' else 'mod.ff')
                    if kind == 'link':
                        info.type = tarfile.SYMTYPE
                        info.linkname = '/etc/passwd'
                        bundle.addfile(info)
                    else:
                        info.size = 1
                        bundle.addfile(info, io.BytesIO(b'x'))
                        if kind == 'duplicate':
                            bundle.addfile(info, io.BytesIO(b'x'))
                destination = root / kind
                with self.assertRaises(ValueError):
                    deploy.extract_release(archive, destination, 'a' * 40)
                self.assertFalse(destination.exists())

    def test_quick_message_buttons_match_native_response_ranges(self):
        source = (ROOT / 'src/ui_mp/wm_quickmessage.menu').read_text()
        for name, count in [('quickcommands', 8), ('quickstatements', 7), ('quickresponses', 6)]:
            chunk = source.split('name "' + name + '"', 1)[1].split('menuDef', 1)[0]
            for number in range(1, count + 1):
                self.assertIn('ui:' + name + ':' + str(number) + '"', chunk)
            self.assertNotIn('ui:' + name + ':' + str(count + 1) + '"', chunk)


if __name__ == '__main__':
    unittest.main()
