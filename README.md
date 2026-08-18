# SSH Agent (Noctalia v5)

A v5 (Luau) port of the v4 QML `ssh-agent` plugin.

## Install (local dev)

```sh
mkdir -p ~/.local/share/noctalia/plugins
cp -r ssh-agent ~/.local/share/noctalia/plugins/ssh-agent
noctalia msg plugins list        # confirm it's discovered
noctalia msg plugins enable martasskv5/ssh-agent
```

Then add the bar widget: `[bar.default] end = ["martasskv5/ssh-agent:status", ...]`
in your `settings.toml`/`config.toml`, or add it from the Add-widget picker
in Settings.

## What changed vs. the v4 (QML) version

- **Language**: QML → Luau. Each old file maps to a new one:
  - `manifest.json` → `plugin.toml` (TOML, new schema)
  - `Main.qml` → `service.luau` (a headless `[[service]]`)
  - `BarWidget.qml` → `widget.luau` (a `[[widget]]`)
  - `Panel.qml` → `panel.luau` (a `[[panel]]`, declarative `ui.*` tree)
  - `Settings.qml` + `settings.json` → `[[widget.setting]]` entries in
    `plugin.toml` + `translations/en.json`. Settings are now edited from
    Settings → Plugins in the host UI; there's no more standalone
    `settings.json` file to hand-edit, and no more `sshVersion` readout in a
    settings panel (it's tracked but currently unused outside the service —
    surface it in the panel if you want it back).
- **No shared object graph**: v4's `pluginApi.mainInstance` let every QML
  file reach into one shared instance. v5 entries are isolated Luau VMs;
  they only communicate via `noctalia.state.set/get/watch` (pub/sub) and
  `onIpc`. The service publishes a `status` key; the widget and panel watch
  it and send back a `command` key for actions.
- **No context menu widget**: v4's `NPopupContextMenu` (Refresh / Start
  Agent / Plugin Settings on right-click) has no v5 equivalent — there's no
  menu primitive in `ui.*`. Left-click now opens the panel (which has
  Refresh/Start/Stop buttons), right-click does a quick refresh, and
  middle-click opens the plugin's settings by default (host behavior).
- **No file picker**: v4's `NFilePicker` for choosing a private key file
  isn't available to plugins in v5. "Add Key" is a path text field instead.
- **Process execution**: v4's `Process { command: [...] }` QML items became
  `noctalia.runAsync(cmd, onResult, timeoutMs)`. Terminal launching now
  prefers the host's `noctalia.runInTerminal()` when no custom terminal
  command is configured, instead of manually probing for kitty/foot/etc.
- **IPC target changed**: `noctalia msg plugin:ssh-agent refresh` (v4)
  becomes `noctalia msg plugin martasskv5/ssh-agent:agent <target> refresh`
  (v5); `<target>` is `focused`, an output name, or `all`.

## Known simplifications

- Sessions are edited inline in the panel rather than in a separate popup.
- No control-center shortcut or launcher provider were added — the v4
  plugin didn't have them either, but they'd be easy to bolt on as
  `[[shortcut]]` / `[[launcher_provider]]` entries if wanted.

Docs: https://docs.noctalia.dev/v5/plugins/development
