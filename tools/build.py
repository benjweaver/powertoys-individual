#!/usr/bin/env python3
"""Extract a pinned Microsoft release without executing its installer."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import struct
import subprocess
import tempfile
import urllib.request
import xml.etree.ElementTree as ET

VERSION = '0.101.2362.0'
HASHES = {
    'arm64': '4c2ae5156b7e4f1f5ba744ba6e1cf6bfe3d9614978356e6b00aa47cab86350db',
    'x64': 'd56fa7130fa68afe553068c15a59a6b24c8dbcc9a0989a43ef0fc5a373230de3',
}


def safe_path(name):
    p = PurePosixPath(name.replace('\\', '/'))
    if p.is_absolute() or '..' in p.parts or ':' in name:
        raise ValueError(f'Unsafe path: {name}')
    return p


def cabinets(data):
    """Read the two Burn cabinets; skip CAB signatures inside compressed data."""
    offset = 0
    while True:
        offset = data.find(b'MSCF', offset)
        if offset < 0:
            return
        if offset + 36 <= len(data):
            size = struct.unpack_from('<I', data, offset + 8)[0]
            if 36 <= size <= len(data) - offset and data[offset+24:offset+26] == b'\x03\x01':
                yield data[offset:offset+size]
                offset += size
                continue
        offset += 4


def msi_strings(folder):
    pool = (folder / '!_StringPool').read_bytes()
    data = (folder / '!_StringData').read_bytes()
    codepage, flags = struct.unpack_from('<HH', pool)
    if flags & 0x8000:
        raise ValueError('Three-byte MSI string references are unsupported')
    strings, position = [''], 0
    for i in range(4, len(pool), 4):
        length, refs = struct.unpack_from('<HH', pool, i)
        # Extended (>64 KiB) strings are outside the pinned release schema.
        if not length and refs:
            raise ValueError('Extended MSI strings are unsupported')
        strings.append(data[position:position+length].decode(f'cp{codepage}' if codepage else 'cp1252'))
        position += length
    if position != len(data):
        raise ValueError('MSI string pool length mismatch')
    return strings


def table(folder, name, widths, strings):
    data = (folder / ('!' + name)).read_bytes()
    if len(data) % sum(map(abs, widths)):
        raise ValueError(f'Unexpected {name} table schema')
    rows = len(data) // sum(map(abs, widths))
    columns, offset = [], 0
    for width in widths:
        size = abs(width)
        values = []
        for r in range(rows):
            value = int.from_bytes(data[offset+r*size:offset+(r+1)*size], 'little')
            values.append(strings[value] if width < 0 else (None if not value else value - (1 << (size*8-1))))
        columns.append(values)
        offset += rows*size
    return list(zip(*columns))


def file_map(folder):
    strings = msi_strings(folder)
    directories = {r[0]: r[1:] for r in table(folder, 'Directory', [-2, -2, -2], strings)}
    components = {r[0]: r[2] for r in table(folder, 'Component', [-2, -2, -2, 2, -2, -2], strings)}
    def directory(key, seen=None):
        seen = set() if seen is None else seen
        if key in seen:
            raise ValueError('Cyclic MSI directory tree')
        seen.add(key)
        # Both architectures place app payloads under INSTALLFOLDER.
        if key == 'INSTALLFOLDER':
            return PurePosixPath('.')
        parent, name = directories[key]
        if not parent:
            return None
        base = directory(parent, seen)
        if base is None:
            return None
        name = name.split(':')[0].split('|')[-1]
        return base if name == '.' else base / safe_path(name)
    result = {}
    for row in table(folder, 'File', [-2, -2, -2, 4, -2, -2, 2, 4], strings):
        identifier, component, name = row[:3]
        parent = directory(components[component])
        if parent is not None:
            result[identifier] = parent / safe_path(name.split('|')[-1])
    return result


def select_awake(root):
    deps = json.loads((root / 'PowerToys.Awake.deps.json').read_text())
    selected = {'PowerToys.Awake.exe', 'PowerToys.Awake.deps.json', 'PowerToys.Awake.runtimeconfig.json'}
    for library in deps['targets'][deps['runtimeTarget']['name']].values():
        for group in ('runtime', 'native'):
            for name in library.get(group, {}):
                if name != '_._':
                    selected.add(PurePosixPath(name).name)
        for name in library.get('resources', {}):
            p = PurePosixPath(name)
            relative = str(PurePosixPath(p.parent.name) / p.name)
            if (root / relative).is_file():
                selected.add(relative)
    # Native / WinRT libraries loaded dynamically, plus C runtime and host.
    selected.update(['PowerToys.GPOWrapper.dll', 'PowerToys.GPOWrapperProjection.dll',
                     'PowerToys.Interop.dll', 'hostfxr.dll', 'hostpolicy.dll',
                     'vcruntime140.dll', 'vcruntime140_1.dll', 'msvcp140.dll'])
    selected.update(str(p.relative_to(root)) for p in (root / 'Assets' / 'Awake').glob('*'))
    # Upstream omits the optional crash dump helper from its installer.
    if not (root / 'createdump.exe').exists():
        selected.discard('createdump.exe')
    missing = sorted(p for p in selected if not (root / safe_path(p)).is_file())
    if missing:
        raise ValueError('Missing Awake dependencies: ' + ', '.join(missing))
    return selected


def build(args):
    if args.output.exists():
        raise ValueError('Output already exists; choose a new directory')
    with tempfile.TemporaryDirectory(prefix='powertoys-individual-') as tmp:
        temp = Path(tmp)
        installer = args.installer or temp / 'setup.exe'
        url = f'https://github.com/microsoft/PowerToys/releases/download/v{VERSION}/PowerToysUserSetup-{VERSION}-{args.arch}.exe'
        if not args.installer:
            print('Downloading official release:', url, flush=True)
            urllib.request.urlretrieve(url, installer)
        data = installer.read_bytes()
        digest = hashlib.sha256(data).hexdigest()
        if digest != HASHES[args.arch]:
            raise ValueError('Installer SHA-256 does not match pinned GitHub release')
        def extract(archive, destination, *patterns):
            subprocess.run([args.seven_zip, 'x', str(archive), '-o'+str(destination), '-y', *patterns],
                           check=True, stdout=subprocess.DEVNULL)
        cabs = list(cabinets(data))
        if len(cabs) != 2:
            raise ValueError('Unexpected Burn cabinet layout')
        for i, cab in enumerate(cabs):
            path = temp / f'burn-{i}.cab'
            path.write_bytes(cab)
            extract(path, temp / f'burn-{i}')
        manifest = ET.parse(temp / 'burn-0' / '0')
        ns = {'b': 'http://wixtoolset.org/schemas/v4/2008/Burn'}
        payloads = [e for e in manifest.findall('b:Payload', ns) if e.get('FilePath', '').endswith('.msi')]
        if len(payloads) != 1:
            raise ValueError('Expected exactly one MSI payload')
        payload = temp / 'burn-1' / safe_path(payloads[0].get('SourcePath'))
        extract(payload, temp / 'msi', '*.cab', '!File', '!Component', '!Directory', '!_StringPool', '!_StringData')
        mapping = file_map(temp / 'msi')
        for cab in sorted((temp / 'msi').glob('*.cab')):
            extract(cab, temp / 'raw')
        root = temp / 'apps'
        for identifier, relative in mapping.items():
            source = temp / 'raw' / safe_path(identifier)
            if not source.is_file():
                raise ValueError('Missing MSI file: ' + identifier)
            target = root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            if target.exists():
                raise ValueError('Duplicate MSI destination: ' + str(relative))
            shutil.copyfile(source, target)
        selected = select_awake(root)
        args.output.mkdir(parents=True)
        for relative in sorted(selected):
            destination = args.output / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(root / relative, destination)
        project = Path(__file__).resolve().parent.parent
        for name in ('Awake.cmd', 'README-portable.txt', 'Set-Startup.ps1', 'Start-Awake.ps1', 'Enable Startup.cmd', 'Disable Startup.cmd', 'Startup Status.cmd'):
            shutil.copyfile(project / name, args.output / name)
        shutil.copytree(project / 'third-party', args.output / 'third-party')
        for name in ('License.rtf', 'Notice.md'):
            shutil.copyfile(root / name, args.output / 'third-party' / name)
        inventory = {p: hashlib.sha256((args.output / p).read_bytes()).hexdigest() for p in sorted(selected)}
        (args.output / 'package.json').write_text(json.dumps({
            'utility': 'Awake', 'version': VERSION, 'architecture': args.arch,
            'source': url, 'installer_sha256': digest, 'files': inventory,
            'runtime_tested': False,
            'launcher_files': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in args.output.iterdir() if p.suffix in ('.cmd', '.ps1')},
        }, indent=2) + '\n')
        print(f'Packaged {len(selected)} payload files; {sum((args.output/p).stat().st_size for p in selected)/1024**2:.1f} MiB')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--arch', choices=HASHES, default='arm64')
    parser.add_argument('--seven-zip', default='7zz', help='Path to official 7-Zip executable (7zz or 7z)')
    parser.add_argument('--installer', type=Path, help='Optional cached official release EXE')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    try:
        build(args)
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, f'Build failed: {error}\n')
