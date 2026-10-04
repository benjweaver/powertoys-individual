import json
from pathlib import Path
import sys
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from build import safe_path, select_awake, table
import tempfile

class ExtractionTests(unittest.TestCase):
    def test_rejects_escape_paths(self):
        for value in ('../outside', '/absolute', 'C:\\outside', 'foo/../../outside'):
            with self.assertRaises(ValueError):
                safe_path(value)
        self.assertEqual(str(safe_path('Assets\\Awake\\Awake.ico')), 'Assets/Awake/Awake.ico')

    def test_msi_column_major_integer_and_string_decoding(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            # Two string refs, then two biased signed 32-bit integers.
            (folder/'!Example').write_bytes(b'\x01\x00\x02\x00\x05\x00\x00\x80\x00\x00\x00\x00')
            self.assertEqual(table(folder, 'Example', [-2, 4], ['', 'one', 'two']), [('one', 5), ('two', None)])

    def test_missing_required_dependencies_fail_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root/'PowerToys.Awake.deps.json').write_text(json.dumps({
                'runtimeTarget': {'name': 'test'}, 'targets': {'test': {'lib': {'runtime': {'Needed.dll': {}}}}}
            }))
            with self.assertRaisesRegex(ValueError, 'Needed.dll'):
                select_awake(root)

if __name__ == '__main__':
    unittest.main()
