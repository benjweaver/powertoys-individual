import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import build_many


class RecipeTests(unittest.TestCase):
    def test_every_recipe_excludes_suite_runner_and_settings(self):
        for recipe in build_many.RECIPES.values():
            entries=recipe['executables']+recipe['modules']+recipe['extras']
            self.assertNotIn('PowerToys.exe', entries)
            self.assertNotIn('WinUI3Apps/PowerToys.Settings.exe', entries)
            self.assertNotIn('PowerToysSparse.msix', entries)

    def test_runtime_copy_manifest_rejects_escape(self):
        with tempfile.TemporaryDirectory() as t:
            root=Path(t);(root/'WinUI3Apps').mkdir()
            (root/'WinUI3Apps/hardlinks.txt').write_text('../outside.dll\n')
            with self.assertRaises(ValueError):
                build_many.materialize_runtime(root)

    def test_missing_managed_dependency_fails(self):
        with tempfile.TemporaryDirectory() as t:
            root=Path(t);(root/'Test.exe').write_bytes(b'')
            (root/'Test.deps.json').write_text(json.dumps({'runtimeTarget':{'name':'test'},'targets':{'test':{'app':{'runtime':{'Missing.dll':{}}}}}}))
            recipe={'modules':[],'executables':['Test.exe'],'extras':[],'assets':[]}
            with self.assertRaisesRegex(ValueError,'Missing dependency'):
                build_many.select(root,recipe)

    def test_import_and_delay_import_resolution(self):
        data=bytearray(1024)
        data[:2]=b'MZ';struct.pack_into('<I',data,60,128)
        data[128:132]=b'PE\0\0';struct.pack_into('<H',data,134,1)
        struct.pack_into('<H',data,148,240)
        struct.pack_into('<H',data,152,0x20b)
        struct.pack_into('<II',data,152+112+8,0x1000,40)
        struct.pack_into('<II',data,152+112+13*8,0x1040,64)
        struct.pack_into('<IIII',data,392+8,512,0x1000,512,512)
        struct.pack_into('<I',data,512+12,0x1100)
        struct.pack_into('<II',data,576,1,0x1120)
        data[768:780]=b'first.dll\0\0\0'
        data[800:811]=b'second.dll\0'
        with tempfile.TemporaryDirectory() as t:
            path=Path(t)/'test.exe';path.write_bytes(data)
            self.assertEqual(build_many.pe_imports(path),{'first.dll','second.dll'})


if __name__=='__main__':unittest.main()
