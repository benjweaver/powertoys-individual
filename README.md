# PowerToys Individual

Run selected Microsoft PowerToys utilities without installing the entire suite.
The first recipe packages **Awake**, using unmodified binaries from Microsoft's
official release. This is a community packaging experiment, not an official
Microsoft product.

## Status

- Awake ARM64: extraction and dependency inventory verified; Windows runtime test pending.
- Awake x64: recipe available; validation pending.
- Other utilities: not supported yet. Each needs its own dependency and standalone-launch review.

The suite installer is downloaded as a source archive, **never executed**.
No PowerToys runner, settings application, shell extensions, services, or other
utility executables are included. Awake does need some shared PowerToys libraries
and the bundled .NET runtime. The ARM64 output is approximately 205 MiB.

## Build

Requirements: Python 3.10+ and official [7-Zip](https://www.7-zip.org/download.html).
Works on macOS or Windows; the output runs on Windows only.

```sh
python3 tools/build.py --arch arm64 --seven-zip /path/to/7zz --output dist/Awake-arm64
python3 tools/build.py --arch x64 --seven-zip /path/to/7zz --output dist/Awake-x64
```

On Windows use `python` and `--seven-zip "C:\Program Files\7-Zip\7z.exe"`.
An optional `--installer /path/to/official.exe` uses a cached download. The builder
pins PowerToys v0.101.2362.0 and checks the official release asset's SHA-256 before
extracting anything. It refuses unknown layouts and missing required dependencies.
Existing output directories are never overwritten.

## Use on Windows

Copy the whole output folder to Windows. Double-click `Awake.cmd`, then right-click
the Awake tray icon to select a mode or exit. From a terminal:

```bat
Awake.cmd --time-limit=3600 --display-on=true
```

No admin access or PowerToys installation is needed. Keep the files together.
Awake can write logs/settings to its normal local app-data directory. To remove
it, exit Awake and remove its package folder. There is no auto-start registration.
For command-line behavior see [Microsoft's Awake documentation](https://learn.microsoft.com/en-us/windows/powertoys/awake).

## Validate

```sh
python3 -m unittest discover -s tests
```

Inside the Windows 11 UTM VM, with existing Awake/PowerToys closed:

```powershell
powershell -NoProfile -File tests\smoke.ps1 -Package dist\Awake-arm64 -RequirePowerRequest -Report smoke-result.json
```

The smoke test checks all payload hashes, Microsoft's executable signature,
absence of other PowerToys apps, successful launch, a Windows power request,
exit when the bound process ends, and that the active power plan is unchanged.
It only cleans up processes it starts. For desktop/tray verification, launch
`Awake.cmd` in the signed-in user's desktop session (SSH launches aren't visible
there). Physical sleep prevention and lock-screen behavior need a separate manual
check; a VM cannot establish behavior on physical hardware.

## How extraction works

1. Verify the pinned installer hash.
2. Read its Burn cabinets and manifest to locate the MSI payload.
3. Read MSI File/Component/Directory tables to reconstruct actual paths.
4. Select Awake's managed/native runtime dependencies from its `.deps.json`.
5. Add native libraries loaded dynamically, runtime host libraries, and tray icons.
6. Preserve available satellite resources and upstream legal notices; write a
   SHA-256 inventory to `package.json`.

The upstream installer omits a few optional satellite resources and
`createdump.exe`; the recipe preserves the same omissions. It includes the full
runtime described by Awake rather than attempting unsupported .NET trimming.

Downloads and build output stay outside Git. Future recipes should prove they
work without the runner before being added. Version updates need new official
hashes and a repeat of the extraction and Windows smoke checks.

Upstream: [microsoft/PowerToys](https://github.com/microsoft/PowerToys).
