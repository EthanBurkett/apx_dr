"""Public-repository boundaries and SDK-free validation behavior."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
import sys
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from repo_audit import credential_errors, forbidden, link_errors
from validate import inspect

ROOT = Path(__file__).resolve().parents[1]


class Repository(unittest.TestCase):
    def test_private_and_generated_paths_are_rejected_at_any_depth(self):
        for name in ("config/private.cfg", "build/nested/private.cfg", "content-check/mod.ff",
                     ".env", ".env.production", "config/private.backup.cfg", "server/secret.pem"):
            self.assertTrue(forbidden(name), name)
        for name in ("config/private.example.cfg", "assets/images/test.iwi",
                     "server/bin/apx_cod4x_dedrun.exe", "src/weapons/mp/knife", "tools/build/Cache.ps1"):
            self.assertFalse(forbidden(name), name)

    def test_credentials_are_detected_without_echoing_values(self):
        errors = credential_errors("public.cfg", 'set rcon_password "DO_NOT_ECHO"\nset dr_admin_loginpass_0 "OTHER_SECRET"\n')
        self.assertEqual(len(errors), 2)
        self.assertTrue(all("redacted" in error for error in errors))
        self.assertNotIn("DO_NOT_ECHO", str(errors))
        self.assertNotIn("OTHER_SECRET", str(errors))
        self.assertEqual(credential_errors("example.cfg", '// set rcon_password "sample"\nset g_password ""\n'), [])

    def test_local_links_resolve_relative_to_document_and_cannot_escape(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); (root / "docs").mkdir()
            path = root / "docs/index.md"; (root / "target.md").write_text("ok")
            path.write_text("[ok](../target.md#section)\n[remote](https://example.com)\n[missing](no.md)\n[escape](../../outside.md)")
            errors = link_errors(root, path)
            self.assertEqual(len(errors), 2)
            self.assertTrue(any("no.md" in error for error in errors))

    def test_validator_never_opens_private_config_and_checks_local_dependencies(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for folder in ("src/braxi", "src/mp", "manifests", "config"):
                (root / folder).mkdir(parents=True)
            (root / "project.json").write_text(json.dumps({
                "sourceRoots": ["src"], "manifestDirectory": "manifests",
                "looseConfigs": [{"source":"config/server.cfg","path":"server.cfg"},
                                 {"source":"config/private.cfg","path":"config/private.cfg","optional":True}]}))
            (root / "config/server.cfg").write_text("exec config/private.cfg\n")
            (root / "config/private.cfg").write_text("THIS_MUST_NOT_BE_READ")
            for table in ("characterTable", "sprayTable", "itemTable", "abilityTable"):
                (root / f"src/mp/{table}.csv").write_text("1,0,1\n")
            for config in ("dr_songs.cfg", "dr_sprays.cfg"):
                (root / "config" / config).write_text("")
            script = root / "src/braxi/main.gsc"
            script.write_text('main() { maps\\mp\\_utility::helper(); braxi\\missing::helper(); }\n')
            (root / "manifests/00.csv").write_text("rawfile,braxi/main.gsc\n")
            original = Path.read_text
            def safe_read(path, *args, **kwargs):
                if path.name == "private.cfg":
                    raise AssertionError("Private config opened")
                return original(path, *args, **kwargs)
            with patch.object(Path, "read_text", safe_read):
                errors, _, _ = inspect(root, root / "no-sdk", source_only=True)
            self.assertTrue(any("braxi/missing.gsc" in error for error in errors))
            self.assertFalse(any("maps/mp/_utility.gsc" in error for error in errors))

    def test_authoring_originals_are_retained_for_every_optimized_texture(self):
        records = json.loads((ROOT / "ui/texture_optimization.json").read_text())
        for record in records.values():
            path = ROOT / "art/source-images" / (record["originalSHA256"] + ".iwi")
            self.assertTrue(path.is_file(), path.name)
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), record['originalSHA256'])


if __name__ == "__main__":
    unittest.main()
