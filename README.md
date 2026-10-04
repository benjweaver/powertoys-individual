# PowerToys Individual

Run selected Microsoft PowerToys utilities without installing the entire suite.
Packages use Microsoft's unmodified utility binaries, selected dependencies, and
small launchers from this project. This is a community project, not an official
Microsoft product. The installer extracts Microsoft's suite installer without
executing it and leaves out the full PowerToys runner and Settings application.

## Status

**v0.2.0 preview** adds individual packages for every utility in PowerToys
v0.101.2362.0, plus individual Mouse Utilities options and uninstall support.
The earlier **v0.1.1** preview remains available for Awake only.

- Awake ARM64: validated in the Windows 11 UTM VM, including power requests,
  timed expiry, startup Off, hidden console, and native tray On/Off behavior.
- Awake x64: installation succeeded in a user-reported test on an x86-family
  Windows machine. Desktop launch and power-request checks also passed under
  Windows 11 ARM64 emulation. Startup on that machine has not yet been reported.
- 32-bit x86 packages are not provided; packages support x64 and ARM64.
- Preview: 34 module launch, activation, and shutdown smoke checks passed on
  ARM64 (Command Palette after a dependency fix) and x64 under ARM64 emulation.
  Command Not Found loaded in a fresh PowerShell 7 session. Always On Top
  pin/unpin and Peek shortcut passthrough passed functional checks.
- Installer/uninstaller round trips passed for live tray hosts, Explorer integration,
  Command Palette, and Command Not Found, including startup cleanup and preservation.
  Details are in [the validation report](validation/windows11-v0.2.0.json).

These checks establish limited VM behavior. Physical sleep, multiple monitors,
networked Mouse Without Borders, hardware-specific display controls, and each
utility's full feature set still need validation. The preview has no standalone
Settings UI: utilities use their native settings files and any bundled editors.

## One-line install

Run in Windows PowerShell; no GitHub account or GitHub CLI is required:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/benjweaver/powertoys-individual/v0.2.0/Install.ps1))) -Apps Awake,ColorPicker,FancyZones
```

The installer detects ARM64/x64, checks pinned hashes and Microsoft signatures,
and installs under `%LOCALAPPDATA%\PowerToysIndividual`. It adds a Start Menu
shortcut and enables per-user startup. Awake starts **Off**, with its console
hidden. `-NoStartup` disables startup; `-NoLaunch` skips launching immediately.
No admin rights, Python, or 7-Zip are needed for prebuilt packages.

## Preview install and uninstall options

The same one-line installer accepts `-List`, `-Apps All`, and `-Uninstall`.
For locally built ZIPs, add `-PackageDirectory` to the saved installer script.

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/benjweaver/powertoys-individual/v0.2.0/Install.ps1))) -Apps Awake,ColorPicker -Uninstall
```

With a saved copy of the installer:

```powershell
# See every utility and its notes without installing anything.
.\Install.ps1 -List
.\Install.ps1 -Apps Awake,ColorPicker,FancyZones
.\Install.ps1 -Apps All

# Remove selected utilities, or every installed utility from this project.
.\Install.ps1 -Apps Awake,ColorPicker -Uninstall
.\Install.ps1 -Apps All -Uninstall
```

Each installed preview utility also has its own entry in Windows **Settings →
Apps → Installed apps**, with an Uninstall action. Uninstall closes that utility
and removes owned package files, shortcuts, profile entries, and registrations.
It preserves user settings, user-added files, and shared PowerShell/framework
installations. User-added package files are moved into a `Preserved-*` folder
beside the removed version, so they do not block a later reinstall. If Explorer
holds a file open, sign out and back in and retry;
the uninstall entry remains available and startup is disabled.

Exit the full PowerToys suite before installing or removing individual utilities.
Avoid running the suite and individual packages together: they share Microsoft's
settings locations and integration names. Command Not Found needs PowerShell
7.4 or newer and installs pinned Microsoft modules from PowerShell Gallery.
Command Palette registers its own signed MSIX and required framework packages.

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

### Build the preview catalog

Build the small host on Windows with Visual Studio 2022 C++ Build Tools,
ARM64/x64 tools, and the Windows SDK:

```bat
native\build.cmd arm64
native\build.cmd x64
```

The build script defaults to `C:\BuildTools`. If Visual Studio is elsewhere,
pass its `vcvarsall.bat` path as the second argument.

For each architecture, run the catalog builder (repeat with x64 paths):

```sh
python3 tools/build_many.py --arch arm64 --installer /path/to/PowerToysUserSetup-arm64.exe --seven-zip /path/to/7zz --cache work/upstream-payload-arm64 --host /path/to/PowerToysIndividual.exe --output dist/arm64
python3 tools/release_catalog.py --arm64 dist/arm64 --x64 dist/x64
```

The host loads only the selected utility modules and exposes tray activation,
enable/disable, bundled editors, and the native settings folder. Utility
packages include only their selected runtime dependencies and legal notices.

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
Awake writes logs/settings to its normal local app-data directory. For the
v0.1.1 stable package, disable startup, exit Awake through the tray, and remove
its package folder. The preview adds automatic uninstall as described above.
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

Downloads and build output stay outside Git. New recipes must be reviewed and
validated without the runner. Version updates need new official
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

## License

Project scripts are [MIT licensed](LICENSE). Microsoft PowerToys retains its
original MIT license; bundled dependencies retain their own licenses and notices
in each package’s `third-party` directory.
