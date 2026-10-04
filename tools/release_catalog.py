#!/usr/bin/env python3
"""Embed pinned archive and manifest hashes for a complete two-architecture release."""
import argparse
import hashlib
import json
from pathlib import Path
import build_many


def catalog(arm64, x64):
    result={}
    for app,recipe in build_many.RECIPES.items():
        entry={'notes':recipe['notes']}
        for architecture,folder in [('arm64',arm64),('x64',x64)]:
            archive=folder/f'{app}-{architecture}.zip'
            manifest=folder/f'{app}-{architecture}'/'package.json'
            entry[architecture]={'archive':hashlib.sha256(archive.read_bytes()).hexdigest(),'manifest':hashlib.sha256(manifest.read_bytes()).hexdigest()}
        result[app]=entry
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--arm64',type=Path,required=True)
    parser.add_argument('--x64',type=Path,required=True)
    parser.add_argument('--installer',type=Path,default=build_many.PROJECT/'Install.ps1')
    args=parser.parse_args()
    pinned=catalog(args.arm64,args.x64)
    json_text=json.dumps(pinned,indent=2)
    start='# BEGIN CATALOG';end='# END CATALOG'
    text=args.installer.read_text();before=text[:text.index(start)+len(start)];after=text[text.index(end):]
    block="\n$releaseCatalog = @'\n"+json_text+"\n'@ | ConvertFrom-Json\n$catalog=@{}\nforeach($entry in $releaseCatalog.PSObject.Properties){$catalog[$entry.Name]=@{arm64=$entry.Value.arm64;x64=$entry.Value.x64;notes=$entry.Value.notes}}\n"
    args.installer.write_text(before+block+after)
    print('Pinned',len(pinned),'utilities for ARM64 and x64')
