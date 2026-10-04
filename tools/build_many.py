#!/usr/bin/env python3
"""Package independent utility recipes from the verified pinned Microsoft release."""
import argparse
import hashlib
import json
import shutil
import struct
import subprocess
import tempfile
import zipfile
from pathlib import Path, PurePosixPath
import build

PROJECT = Path(__file__).resolve().parent.parent
RECIPES = json.loads((PROJECT / 'recipes.json').read_text())


def pe_imports(path):
    data = path.read_bytes()
    if data[:2] != b'MZ':
        return set()
    pe = struct.unpack_from('<I', data, 60)[0]
    if data[pe:pe+4] != b'PE\0\0':
        raise ValueError('Invalid PE image: ' + str(path))
    sections, optional_size = struct.unpack_from('<H12xH', data, pe+6)
    optional = pe+24
    is64 = struct.unpack_from('<H', data, optional)[0] == 0x20b
    directories = optional + (112 if is64 else 96)
    image_base = struct.unpack_from('<Q' if is64 else '<I', data, optional+(24 if is64 else 28))[0]
    section_table = optional + optional_size
    def offset(rva):
        for i in range(sections):
            virtual_size, address, raw_size, raw = struct.unpack_from('<IIII', data, section_table+i*40+8)
            if address <= rva < address+max(virtual_size, raw_size):
                return raw+rva-address
        raise ValueError('Invalid PE RVA: ' + str(path))
    found = set()
    for index, stride, name_offset in [(1,20,12),(13,32,4)]:
        rva, size = struct.unpack_from('<II', data, directories+index*8)
        if not rva or not size:
            continue
        start = offset(rva)
        for pos in range(start, start+size, stride):
            row = data[pos:pos+stride]
            if not any(row):
                break
            name = struct.unpack_from('<I', row, name_offset)[0]
            if index == 13 and not (struct.unpack_from('<I', row)[0] & 1):
                name -= image_base
            at = offset(name)
            found.add(data[at:data.index(b'\0',at)].decode('ascii'))
    return found


def materialize_runtime(root):
    # The upstream MSI copies its deduplicated runtime into WinUI3Apps.
    manifest = root/'WinUI3Apps'/'hardlinks.txt'
    if not manifest.exists():
        raise ValueError('Missing upstream runtime copy manifest')
    for line in manifest.read_text(encoding='utf-8-sig').splitlines():
        line=line.strip()
        if not line or line.startswith('#'):
            continue
        relative=build.safe_path(line)
        source=root/relative
        target=root/'WinUI3Apps'/relative
        if not source.exists():
            raise ValueError('Missing shared runtime source: '+line)
        if not target.exists():
            target.parent.mkdir(parents=True,exist_ok=True)
            target.hardlink_to(source)


def select(root, recipe):
    selected = set(recipe['modules']+recipe['executables']+recipe['extras'])
    for asset in recipe['assets']:
        selected.update(str(p.relative_to(root)) for p in (root/asset).rglob('*') if p.is_file())
    # Managed dependency manifests select their complete self-contained runtime.
    manifests = [root/str(PurePosixPath(p).with_suffix('.deps.json')) for p in recipe['executables']]
    manifests += [p for asset in recipe['assets'] for p in (root/asset).rglob('*.deps.json')]
    for manifest in manifests:
        if not manifest.exists():
            continue
        base = manifest.parent
        selected.add(str(manifest.relative_to(root)))
        runtimeconfig = manifest.with_name(manifest.name.replace('.deps.json','.runtimeconfig.json'))
        if runtimeconfig.exists():
            selected.add(str(runtimeconfig.relative_to(root)))
        deps = json.loads(manifest.read_text())
        for library in deps['targets'][deps['runtimeTarget']['name']].values():
            for group in ('runtime','native'):
                for name in library.get(group,{}):
                    if name == '_._':
                        continue
                    path = base/PurePosixPath(name).name
                    if not path.exists() and (root/path.name).exists():
                        path = root/path.name
                    if path.name == 'createdump.exe' and not path.exists():
                        continue
                    selected.add(str(path.relative_to(root)))
            for name in library.get('resources',{}):
                p = PurePosixPath(name)
                path = base/p.parent.name/p.name
                if path.is_file():
                    selected.add(str(path.relative_to(root)))
    # Shared helpers dynamically loaded by native and managed utilities.
    for base in (root, root/'WinUI3Apps'):
        for name in ('PowerToys.Interop.dll','PowerToys.GPOWrapper.dll','PowerToys.GPOWrapperProjection.dll'):
            if (base/name).exists():
                selected.add(str((base/name).relative_to(root)))
    if any(p.startswith('WinUI3Apps/') and p.endswith('.exe') for p in selected):
        base=root/'WinUI3Apps'
        # Self-contained WinAppSDK resources and native activation libraries.
        for p in base.iterdir():
            if p.is_file() and (p.suffix in ('.pri','.winmd') or (p.suffix=='.dll' and not p.name.startswith('PowerToys.'))):
                selected.add(str(p.relative_to(root)))
        for folder in ('Microsoft.UI.Xaml',):
            selected.update(str(p.relative_to(root)) for p in (base/folder).rglob('*') if p.is_file())
    # Resolve native imports from the DLL's folder, then the package root.
    index = {str(p.relative_to(root)).lower():p for p in root.rglob('*') if p.is_file()}
    queue=list(selected); visited=set()
    while queue:
        relative=queue.pop()
        if relative in visited:
            continue
        visited.add(relative)
        p=root/build.safe_path(relative)
        if not p.exists():
            raise ValueError('Missing dependency: '+relative)
        if p.suffix.lower() not in ('.exe','.dll'):
            continue
        for name in pe_imports(p):
            candidates=[str(p.parent.relative_to(root)/name).lower(),name.lower(),('WinUI3Apps/'+name).lower()]
            dependency=next((index[c] for c in candidates if c in index),None)
            if dependency:
                child=str(dependency.relative_to(root))
                if child not in selected:
                    selected.add(child);queue.append(child)
    missing = sorted(p for p in selected if not (root/build.safe_path(p)).is_file())
    if missing:
        raise ValueError('Missing dependencies: '+', '.join(missing))
    return selected


def extract(installer, arch, seven_zip, destination):
    if destination.exists():
        raise ValueError('Extraction output already exists')
    data=installer.read_bytes()
    if hashlib.sha256(data).hexdigest()!=build.HASHES[arch]:
        raise ValueError('Installer hash mismatch')
    import xml.etree.ElementTree as ET
    with tempfile.TemporaryDirectory(prefix='powertoys-extract-') as t:
        temp=Path(t)
        def unpack(archive, output, *patterns):
            subprocess.run([seven_zip,'x',str(archive),'-o'+str(output),'-y',*patterns],check=True,stdout=subprocess.DEVNULL)
        cabs=list(build.cabinets(data))
        if len(cabs)!=2:
            raise ValueError('Unexpected Burn cabinet layout')
        for i,cab in enumerate(cabs):
            path=temp/f'burn-{i}.cab';path.write_bytes(cab);unpack(path,temp/f'burn-{i}')
        ns={'b':'http://wixtoolset.org/schemas/v4/2008/Burn'}
        manifests=ET.parse(temp/'burn-0'/'0').findall('b:Payload',ns)
        payloads=[e for e in manifests if e.get('FilePath','').endswith('.msi')]
        if len(payloads)!=1:raise ValueError('Expected one MSI')
        msi=temp/'burn-1'/build.safe_path(payloads[0].get('SourcePath'))
        unpack(msi,temp/'msi','*.cab','!File','!Component','!Directory','!_StringPool','!_StringData')
        for cab in sorted((temp/'msi').glob('*.cab')):unpack(cab,temp/'raw')
        destination.mkdir(parents=True)
        for identifier,relative in build.file_map(temp/'msi').items():
            target=destination/relative;target.parent.mkdir(parents=True,exist_ok=True)
            if target.exists():raise ValueError('Duplicate MSI destination')
            shutil.copyfile(temp/'raw'/build.safe_path(identifier),target)
        materialize_runtime(destination)
        (destination/'_source.json').write_text(json.dumps({'version':build.VERSION,'architecture':arch,'sha256':build.HASHES[arch]}))


def package(root, arch, app, host, output):
    recipe=RECIPES[app]
    selected=build.select_awake(root) if app=='Awake' else select(root,recipe)
    folder=output/f'{app}-{arch}'
    if folder.exists():raise ValueError('Package output exists: '+str(folder))
    folder.mkdir(parents=True)
    for relative in sorted(selected):
        dst=folder/relative;dst.parent.mkdir(parents=True,exist_ok=True)
        dst.hardlink_to(root/relative)
    launcher=['LICENSE','Uninstall-App.ps1']
    if app=='Awake':
        launcher+=['Awake.cmd','Start-Awake.ps1','Set-Startup.ps1','Enable Startup.cmd','Disable Startup.cmd','Startup Status.cmd','README-portable.txt']
    else:
        launcher+=['Start-App.ps1','Setup-App.ps1']
        if recipe['modules']:
            shutil.copyfile(host,folder/'PowerToysIndividual.exe')
        text='[App]\nName='+app+'\n'+''.join(f'Module{i}={m}\n' for i,m in enumerate(recipe['modules']))
        if recipe['editor']:text+='Editor='+recipe['editor']+'\n'
        if recipe.get('editor_event'):text+='EditorEvent='+recipe['editor_event']+'\n'
        text+='Icon='+(recipe['executables'][0] if recipe['executables'] else recipe['modules'][0] if recipe['modules'] else '')+'\n'
        (folder/'app.ini').write_text(text)
    for name in launcher:shutil.copyfile(PROJECT/name,folder/name)
    shutil.copytree(PROJECT/'third-party',folder/'third-party')
    for name in ('License.rtf','Notice.md'):shutil.copyfile(root/name,folder/'third-party'/name)
    # Own wrappers, runtime resources, and license files are all inventoried.
    files={str(p.relative_to(folder)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(folder.rglob('*')) if p.is_file()}
    manifest={'utility':app,'version':build.VERSION,'architecture':arch,'installer_sha256':build.HASHES[arch],
              'files':files,'launcher_files':{p:files[p] for p in launcher},'signature_targets':recipe['modules']+recipe['executables'],
              'runtime_tested':False,'notes':recipe['notes']}
    if app=='Awake':manifest['signature_targets']=['PowerToys.Awake.exe']
    (folder/'package.json').write_text(json.dumps(manifest,indent=2)+'\n')
    archive=output/f'{app}-{arch}.zip'
    with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=1) as z:
        for p in sorted(folder.rglob('*')):
            if p.is_file():z.write(p,str(p.relative_to(output)))
    return hashlib.sha256(archive.read_bytes()).hexdigest()


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--arch',choices=build.HASHES,required=True)
    parser.add_argument('--installer',type=Path,required=True)
    parser.add_argument('--seven-zip',required=True)
    parser.add_argument('--cache',type=Path,required=True)
    parser.add_argument('--host',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--apps',nargs='+',default=list(RECIPES))
    args=parser.parse_args()
    if hashlib.sha256(args.installer.read_bytes()).hexdigest()!=build.HASHES[args.arch]:raise ValueError('Installer hash mismatch')
    if not args.cache.exists():extract(args.installer,args.arch,args.seven_zip,args.cache)
    receipt=json.loads((args.cache/'_source.json').read_text())
    if receipt!={'version':build.VERSION,'architecture':args.arch,'sha256':build.HASHES[args.arch]}:raise ValueError('Cache source identity mismatch')
    args.output.mkdir(parents=True,exist_ok=True)
    results={}
    for app in args.apps:
        results[app]=package(args.cache,args.arch,app,args.host,args.output)
        print(app,args.arch,results[app],flush=True)
    (args.output/'archive-hashes.json').write_text(json.dumps(results,indent=2)+'\n')
