PowerToys Awake — standalone community package

Double-click Awake.cmd to start Off. Click the Awake tray icon and choose
Keep awake indefinitely to turn it On, or Off to allow normal sleep.
The menu also offers timed modes and Exit. The debug console is hidden. No PowerToys runner is included.

From a terminal:
  Awake.cmd --time-limit=3600 --display-on=true

Keep all files together. The included .NET runtime is required; this is not a
single EXE. No installer, administrator rights, or PowerToys settings app is
needed. Awake may write its logs/settings under your local app-data folder.

To start Awake whenever you sign in, double-click Enable Startup.cmd.
Disable Startup.cmd removes its startup shortcut; Startup Status.cmd checks it.
Keep the folder in its final location before enabling startup. This starts
Awake after sign-in, rather than as a service before sign-in.

This is a community standalone distribution. It retains unmodified
Microsoft release binaries. See third-party for upstream legal notices.
