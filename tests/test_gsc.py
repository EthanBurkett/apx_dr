"""Source inspector regressions. Run: python -m unittest discover -s tests -v."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from gsc import functions, mask, qualify


class SourceInspectionTests(unittest.TestCase):
    def test_comments_and_strings_do_not_change_offsets_or_structure(self):
        text = 'main() { text = "https://example/{x}"; /* }\n */ call(); // }\n}'
        code = mask(text)
        self.assertEqual(len(code), len(text))
        self.assertEqual(code.count('\n'), text.count('\n'))
        self.assertEqual(code.count('{'), 1)
        self.assertEqual(code.count('}'), 1)
        self.assertIn('call()', code)

    def test_nested_blocks_are_not_function_definitions(self):
        text = 'first(x) {\n if (x) {\n while (x) { x--; }\n }\n}\nsecond() {}'
        found = functions(text)
        self.assertEqual([fn.name for fn in found], ['first', 'second'])
        self.assertEqual(found[0].params, 'x')
        self.assertEqual(text[found[1].body_start:found[1].end], '{}')

    def test_commented_functions_are_ignored(self):
        text = '/*\nold() {}\n*/\nlive(a, b) // a comment\n{\n return "\\\"}";\n}'
        found = functions(text)
        self.assertEqual([fn.name for fn in found], ['live'])
        self.assertEqual(found[0].params, 'a, b')

    def test_unclosed_function_fails(self):
        with self.assertRaises(ValueError):
            functions('main() {\n if (true) {}')

    def test_cross_module_calls_keep_receivers_and_threading(self):
        source = '{\n self thread Spawn();\n level thread endRound();\n endRound();\n}'
        result = qualify(source, {'spawn': 'braxi\\_player', 'endround': 'braxi\\_rounds'}, 'braxi\\_rounds')
        self.assertIn('self thread braxi\\_player::Spawn();', result)
        self.assertIn('level thread endRound();', result)

    def test_qualified_calls_and_text_are_not_rewritten(self):
        source = '{ braxi\\_mod::spawn(); value = "spawn()"; /* spawn() */ }'
        self.assertEqual(qualify(source, {'spawn': 'braxi\\_player'}, 'braxi\\_rounds'), source)

    def test_local_function_pointers_can_be_moved(self):
        source = '{ level.callback = ::spawn; other\\file::spawn(); }'
        result = qualify(source, {'spawn': 'braxi\\_player'}, 'braxi\\_rounds')
        self.assertIn('= braxi\\_player::spawn;', result)
        self.assertIn('other\\file::spawn()', result)


if __name__ == '__main__':
    unittest.main()
