# PowerToys Individual

Run selected Microsoft PowerToys utilities without installing the entire suite.
The first recipe packages **Awake**, using unmodified binaries from Microsoft's
official release. This is a community packaging experiment, not an official
Microsoft product.

## Status

- Awake ARM64: validated in the Windows 11 UTM VM, including desktop launch, power requests, timed expiry, startup Off, hidden console, and On/Off behavior.
- Awake x64: desktop launch and power-request smoke test passed under Windows 11 ARM64 emulation. Native x64 hardware and startup are not yet tested.
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

Copy the whole output folder to its final location on Windows. Double-click
`Awake.cmd`: it opens the tray app **Off**. Click the tray icon and select
**Keep awake indefinitely** to turn it On, or **Off** to allow normal sleep.
Timed modes and Exit are also available. This uses Awake's native menu; both
left and right clicks open it. The debug console is hidden.

Double-click **Enable Startup.cmd** to start it automatically when you sign in.
It always resets to **Off** at sign-in, including if it was On last time.
**Disable Startup.cmd** removes only this package's per-user startup shortcut.
**Startup Status.cmd** checks the setting. Move the folder before enabling startup;
if you move it later, re-enable startup from its new location.

Advanced command-line mode bypasses the menu launcher; for example:

```bat
Awake.cmd --time-limit=3600 --display-on=true
```

No admin access or PowerToys installation is needed. Keep the files together.
Awake can write logs/settings to its normal local app-data directory. To remove
it, disable startup, exit Awake through the tray, and remove its package folder.
Startup is enabled in the test VM; new packages require the user to enable it.
For command-line behavior see [Microsoft's Awake documentation](https://learn.microsoft.com/en-us/windows/powertoys/awake).

## Validate

```sh
python3 -m unittest discover -s tests
```

Inside the Windows 11 UTM VM, with existing Awake/PowerToys closed:

```powershell
& ([scriptblock]::Create((Get-Content tests\Invoke-DesktopSmoke.ps1 -Raw))) -Package dist\Awake-arm64 -Report smoke-result.json -SmokeScript tests\smoke.ps1
```

The smoke test checks all payload hashes, Microsoft's executable signature,
absence of other PowerToys apps, successful launch, a Windows power request,
exit when the bound process ends, and that the active power plan is unchanged.
It only cleans up processes it starts. The helper creates and removes a temporary interactive scheduled task so the
test runs in the signed-in desktop session. The user must be signed in. SSH
processes run in a different session and do not establish desktop power behavior.
No execution-policy setting is changed.

After enabling startup and rebooting, test startup and On/Off behavior with:

```powershell
& ([scriptblock]::Create((Get-Content tests\Invoke-DesktopSmoke.ps1 -Raw))) -Package dist\Awake-arm64 -Report startup-result.json -SmokeScript tests\startup.ps1 -StartupTest
``` Physical sleep prevention and lock-screen behavior need a separate manual
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

## Tray menu fix

Raw standalone command-line mode does not create a tray menu in the pinned
upstream release (`TrayMenu` stays null). `Start-Awake.ps1` creates/preserves
Awake's own settings, sets mode 0, and launches with `--use-pt-config`. This
initializes the native menu without running or installing the PowerToys suite.
It hides only Awake's allocated console and preserves the native Exit option.
Settings are stored in `%LOCALAPPDATA%\Microsoft\PowerToys\Awake\settings.json`.
An independently running Awake from another installation is refused.
